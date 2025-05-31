/*
 * RadioPlayerService.kt
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

package com.cheebeez.radio_player

import android.util.Log
import android.app.PendingIntent
import android.os.Bundle
import android.content.Intent
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.MediaItem
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.Metadata
import androidx.media3.common.MediaMetadata
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.extractor.metadata.icy.IcyInfo
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.common.ForwardingPlayer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/// Manages the MediaSession and ExoPlayer instance for background audio playback.
class RadioPlayerService : MediaSessionService(), Player.Listener {

    companion object {
        private const val TAG = "RadioPlayerService"
        const val METADATA_EXTRA_IS_INITIAL = "com.cheebeez.radio_player.IS_INITIAL_METADATA"

        // Custom Commands
        const val CUSTOM_COMMAND_SET_STATION = "com.cheebeez.radio_player.SET_STATION"
        const val CUSTOM_COMMAND_SET_CUSTOM_METADATA = "com.cheebeez.radio_player.SET_CUSTOM_METADATA"
        const val CUSTOM_COMMAND_SET_ITUNES_ARTWORK_PARSING = "com.cheebeez.radio_player.SET_ITUNES_ARTWORK_PARSING"
        const val CUSTOM_COMMAND_SET_IGNORE_ICY = "com.cheebeez.radio_player.SET_IGNORE_ICY"
    }

    var metadataArtwork: ByteArray? = null
    var ignoreIcy: Boolean = false
    var itunesArtworkParser: Boolean = false

    private var defaultArtwork: ByteArray? = null
    private var mediaSession: MediaSession? = null
    private var defaultTitle = ""

    // Internal state for current track metadata
    private var currentArtistMeta: String? = null
    private var currentSongTitleMeta: String? = null
    private var currentArtworkUrlMeta: String? = null

    private lateinit var player: ExoPlayer
    private lateinit var forwardingPlayer: ForwardingPlayer
    private val serviceJob = SupervisorJob()
    private val serviceScope = CoroutineScope(Dispatchers.Main + serviceJob)

    /// Returns the MediaSession instance for controllers.
    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }

    /// Releases resources when the service is destroyed.
    override fun onDestroy() {
        mediaSession?.run {
            player.removeListener(this@RadioPlayerService)
            player.release()
            release()
            mediaSession = null
        }

        serviceJob.cancel()
        super.onDestroy()
    }

    /// Stops all players and the service itself when the app task is removed.
    override fun onTaskRemoved(intent: Intent?) {
        pauseAllPlayersAndStopSelf()
    }

    /// Forces the service to enter or update its foreground state.
    /// TODO: It might be necessary to pass true until onTaskRemoved is called, and then false.
    override fun onUpdateNotification(session: MediaSession, startInForegroundRequired: Boolean) {
        super.onUpdateNotification(session, startInForegroundRequired)
    }

    /// Initializes the player and media session when the service is created.
    override fun onCreate() {
        super.onCreate()

        // Setup audio focus and attributes.
        val audioAttributes: AudioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.CONTENT_TYPE_MUSIC)
            .build()

        // Create ExoPlayer instance.
        player = ExoPlayer.Builder(this).build().apply {
            setAudioAttributes(audioAttributes, true)
            setHandleAudioBecomingNoisy(true)
            setWakeMode(C.WAKE_MODE_NETWORK)
            this.addListener(this@RadioPlayerService)
        }

        // PendingIntent to launch the app's UI when the notification is clicked.
        val activityIntent = packageManager?.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }

        // Create MediaSession.
        mediaSession = MediaSession.Builder(this, CustomForwardingPlayer(player))
            .setCallback(MediaSessionCallback(this@RadioPlayerService))
            .setId("RadioPlayerSession_${System.currentTimeMillis()}")
            .apply {
                activityIntent?.let { setSessionActivity(it) }
            }
            .build()
    }

    /// Sets the radio station URL and initial metadata.
    fun setStation(title: String, url: String, artworkBytes: ByteArray? = null) {
        defaultTitle = title
        defaultArtwork = artworkBytes

        // Reset current track metadata when station changes
        currentArtistMeta = null 
        currentSongTitleMeta = null
        currentArtworkUrlMeta = null
        metadataArtwork = null

        // Prepare initial MediaMetadata for the new station.
        val mediaMetadataBuilder = MediaMetadata.Builder()
            .setStation(defaultTitle)
            .setTitle(defaultTitle)
            .setMediaType(MediaMetadata.MEDIA_TYPE_RADIO_STATION)
            .setExtras(Bundle().apply { putBoolean(METADATA_EXTRA_IS_INITIAL, true) })

        if (defaultArtwork != null) {
            mediaMetadataBuilder.setArtworkData(defaultArtwork!!, MediaMetadata.PICTURE_TYPE_FRONT_COVER)
        }

        // Build the MediaItem for the new station.
        val  mediaItem = MediaItem.Builder()
            .setUri(url)
            .setMediaId(url)
            .setMediaMetadata(mediaMetadataBuilder.build())
            .build()

        // Set the new MediaItem to the player.
        player.setMediaItem(mediaItem!!, true)
    }

    /// Updates the player's metadata with new track information.
    fun setMetadata(artist: String, songTitle: String, artworkUrl: String?) {

        // Check if metadata has actually changed
        if (artist == currentArtistMeta && songTitle == currentSongTitleMeta) {
            return
        }

        currentArtistMeta = artist
        currentSongTitleMeta = songTitle
        currentArtworkUrlMeta = artworkUrl

        serviceScope.launch {
            // Optionally parse artwork URL from iTunes.
            if (itunesArtworkParser && artworkUrl.isNullOrEmpty())
                currentArtworkUrlMeta = parseArtworkFromItunes(artist, songTitle)

            // Download artwork image if URL is available.
            metadataArtwork = if (currentArtworkUrlMeta != null) downloadImage(currentArtworkUrlMeta) else null

            // Update MediaMetadata for the notification and system UI.
            val currentMediaItem = player.currentMediaItem ?: return@launch

            val newMediaMetadataBuilder = MediaMetadata.Builder()
                .setStation(currentMediaItem!!.mediaMetadata.station)
                .setArtist(artist.ifEmpty { null }) 
                .setTitle(songTitle.ifEmpty { defaultTitle })
                .setMediaType(MediaMetadata.MEDIA_TYPE_RADIO_STATION)
                .setExtras(Bundle())

            if (!currentArtworkUrlMeta.isNullOrEmpty()) {
                try {
                    val artworkUri = android.net.Uri.parse(currentArtworkUrlMeta)
                    newMediaMetadataBuilder.setArtworkUri(artworkUri)
                } catch (e: Exception) {
                    Log.w(TAG, "Error parsing artwork URI: $currentArtworkUrlMeta", e)
                }
            }

            if (metadataArtwork != null) {
                newMediaMetadataBuilder.setArtworkData(metadataArtwork!!, MediaMetadata.PICTURE_TYPE_FRONT_COVER)
            } else if (defaultArtwork != null) {
                newMediaMetadataBuilder.setArtworkData(defaultArtwork!!, MediaMetadata.PICTURE_TYPE_FRONT_COVER)
            }

            val updatedMediaItem = currentMediaItem.buildUpon()
                .setMediaMetadata(newMediaMetadataBuilder.build())
                .build()

            player.replaceMediaItem(player.currentMediaItemIndex, updatedMediaItem)
        }
    }

    /// Handles player errors.
    override fun onPlayerError(error: PlaybackException) {
        super.onPlayerError(error)
        Log.e(TAG, "Player Error: ", error)
    }

    /// Processes incoming ICY (stream) metadata.
    override fun onMetadata(rawMetadata: Metadata) {
        super.onMetadata(rawMetadata)

        if (ignoreIcy || rawMetadata[0] !is IcyInfo) return
    
        val icyInfo: IcyInfo = rawMetadata[0] as IcyInfo
        val streamTitle: String = icyInfo.title ?: return
        if (streamTitle.length == 0) return

        var artist = ""
        var songTitle = streamTitle.trim()
        val artworkUrlFromIcy: String? = icyInfo.url?.takeIf { it.isNotBlank() }

        // Check if songTitle is in "Artist - Title" format
        val parts = streamTitle.split(" - ", limit = 2)
        if (parts.size == 2) {
            artist = parts[0].trim()
            songTitle = parts[1].trim()
        }
 
        setMetadata(artist, songTitle, artworkUrlFromIcy)
    }
}
