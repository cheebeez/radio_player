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
        const val CUSTOM_COMMAND_RESET = "com.cheebeez.radio_player.RESET"
        const val CUSTOM_COMMAND_SET_NAVIGATION_CONTROLS = "com.cheebeez.radio_player.SET_NAVIGATION_CONTROLS"
    }

    var metadataArtwork: ByteArray? = null
    var parseStreamMetadata: Boolean = true
    var lookupOnlineArtwork: Boolean = false

    private var defaultArtwork: ByteArray? = null
    private var mediaSession: MediaSession? = null
    private var defaultTitle = ""
    private var metadataHash: String? = null

    private lateinit var player: ExoPlayer
    private lateinit var customForwardingPlayer: CustomForwardingPlayer

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

        customForwardingPlayer = CustomForwardingPlayer(player)

        // PendingIntent to launch the app's UI when the notification is clicked.
        val activityIntent = packageManager?.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }

        // Create MediaSession.
        mediaSession = MediaSession.Builder(this, customForwardingPlayer)
            .setCallback(MediaSessionCallback(this@RadioPlayerService))
            .setId("RadioPlayerSession_${System.currentTimeMillis()}")
            .apply {
                activityIntent?.let { setSessionActivity(it) }
            }
            .build()
    }

    /// Sets the radio station URL and initial metadata.
    fun setStation(
            title: String, 
            url: String, 
            artworkBytes: ByteArray? = null,
            parseStreamMetadata: Boolean,
            lookupOnlineArtwork: Boolean
        ) {
        defaultTitle = title
        defaultArtwork = artworkBytes
        metadataArtwork = null
        metadataHash = null

        // Update properties based on new parameters
        this.parseStreamMetadata = parseStreamMetadata
        this.lookupOnlineArtwork = lookupOnlineArtwork

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
    fun setMetadata(artist: String?, songTitle: String?, artworkUrl: String?) {

        // Check if metadata has actually changed.
        val newMetadataHash = (artist ?: "_null_") + (songTitle ?: "_null_")
        if (newMetadataHash == metadataHash) return
        metadataHash = newMetadataHash

        serviceScope.launch {
            var currentArtworkUrl = artworkUrl

            // Optionally parse artwork URL from iTunes.
            if (lookupOnlineArtwork && artworkUrl.isNullOrEmpty())
                currentArtworkUrl = parseArtworkFromItunes(artist ?: "", songTitle ?: "")

            // Download artwork image if URL is available.
            metadataArtwork = if (currentArtworkUrl != null) downloadImage(currentArtworkUrl) else null

            // Update MediaMetadata for the notification and system UI.
            val currentMediaItem = player.currentMediaItem ?: return@launch

            val newMediaMetadataBuilder = MediaMetadata.Builder()
                .setStation(currentMediaItem!!.mediaMetadata.station)
                .setArtist(artist) 
                .setTitle(songTitle)
                .setMediaType(MediaMetadata.MEDIA_TYPE_RADIO_STATION)
                .setExtras(Bundle())

            if (!currentArtworkUrl.isNullOrEmpty()) {
                try {
                    val artworkUri = android.net.Uri.parse(currentArtworkUrl)
                    newMediaMetadataBuilder.setArtworkUri(artworkUri)
                } catch (e: Exception) {
                    Log.w(TAG, "Error parsing artwork URI: $currentArtworkUrl", e)
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

    /// Stops playback, removes notification, and fully resets player state for the next station.
    fun reset() {
        player.stop()
        player.clearMediaItems()

        defaultTitle = ""
        defaultArtwork = null
        metadataArtwork = null
        metadataHash = null

        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    /// Sets the visibility of next/previous track controls in the media notification.
    fun setNavigationControls(showNext: Boolean, showPrevious: Boolean) {
        if (!::customForwardingPlayer.isInitialized) return

        customForwardingPlayer.seekToNext = showNext
        customForwardingPlayer.seekToPrevious = showPrevious
    }

    /// Handles player errors.
    override fun onPlayerError(error: PlaybackException) {
        super.onPlayerError(error)
        Log.e(TAG, "Player Error: ", error)
    }

    /// Processes incoming ICY (stream) metadata.
    override fun onMetadata(rawMetadata: Metadata) {
        super.onMetadata(rawMetadata)

        if (!parseStreamMetadata || rawMetadata[0] !is IcyInfo) return

        val icyInfo: IcyInfo = rawMetadata[0] as IcyInfo
        val streamTitle: String = icyInfo.title?.trim() ?: return
        if (streamTitle.isEmpty()) return

        var artist: String? = null
        var songTitle: String? = null
        val artworkUrlFromIcy: String? = icyInfo.url?.takeIf { it.isNotBlank() }

        // Check if songTitle is in "Artist - Title" format
        val parts = streamTitle.split(" - ", limit = 2)

        if (parts.size == 2) {
            artist = parts[0].trim().takeIf { it.isNotEmpty() }
            songTitle = parts[1].trim().takeIf { it.isNotEmpty() }
        } else {
            songTitle = streamTitle.takeIf { it.isNotEmpty() }
        }
 
        setMetadata(artist, songTitle, artworkUrlFromIcy)
    }
}
