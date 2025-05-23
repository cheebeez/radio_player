/*
 *  RadioPlayerService.kt
 *
 *  Created by Ilia Chirkunov <contact@cheebeez.com> on 21.05.2025.
 */

package com.cheebeez.radio_player

import com.cheebeez.radio_player.R
import android.util.Log
import java.net.URL
import java.net.URLEncoder
import org.json.JSONObject
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.app.PendingIntent
import android.content.Intent
import android.os.IBinder
import android.os.Binder
import android.app.Notification
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
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking

import androidx.media3.common.ForwardingPlayer
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import androidx.media3.session.SessionResult

/// Service for plays streaming audio content using ExoPlayer.
class RadioPlayerService : MediaSessionService(), Player.Listener {

    companion object {
        private const val TAG = "RadioPlayerService"
        const val NOTIFICATION_CHANNEL_ID = "radio_channel_id"
        const val NOTIFICATION_ID = 1
        const val ACTION_STATE_CHANGED = "state_changed"
        const val ACTION_STATE_CHANGED_EXTRA = "state"
        const val ACTION_NEW_METADATA = "metadata_changed"
        const val ACTION_NEW_METADATA_EXTRA = "metadata"
    }

    var metadataArtwork: Bitmap? = null
    var ignoreIcy: Boolean = false
    var itunesArtworkParser: Boolean = false
    private var mediaItem: MediaItem? = null
    private var defaultArtwork: Bitmap? = null
    private var mediaSession: MediaSession? = null
    private var defaultTitle = ""
    private var metadata: ArrayList<String>? = null
    private var localBinder = LocalBinder()
    private var playbackState = Player.STATE_IDLE
    private lateinit var player: ExoPlayer
    private lateinit var forwardingPlayer: ForwardingPlayer

    private val localBroadcastManager: LocalBroadcastManager by lazy {
        LocalBroadcastManager.getInstance(this)
    }

    /// Return this instance of RadioPlayerService so clients can call public methods.
    inner class LocalBinder : Binder() {
        fun getService(): RadioPlayerService = this@RadioPlayerService
    }

    ///
    override fun onBind(intent: Intent?): IBinder? {
        return localBinder
    }

    ///
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    ///
    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? =
        mediaSession

    ///
    override fun onDestroy() {
        mediaSession?.run {
            player.removeListener(this@RadioPlayerService)
            player.release()
            release()
            mediaSession = null
        }

        super.onDestroy()
    }

    ///
    override fun onCreate() {
        super.onCreate()

        // Setup audio focus
        val audioAttributes: AudioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.CONTENT_TYPE_MUSIC)
            .build()

        // Создать ExoPlayer.
        player = ExoPlayer.Builder(this).build().apply {
            setAudioAttributes(audioAttributes, true)
            setHandleAudioBecomingNoisy(true)
            setWakeMode(C.WAKE_MODE_LOCAL)
            this.repeatMode = Player.REPEAT_MODE_ONE
            this.addListener(this@RadioPlayerService)
        }

        // PendingIntent для запуска UI приложения при клике на уведомление.
        val activityIntent = packageManager?.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        }

        // Создать MediaSession.
        val mediaSessionBuilder = MediaSession.Builder(this, CustomForwardingPlayer(player))
            .setCallback(MediaSessionCallback())

        if (activityIntent != null) { 
            mediaSessionBuilder.setSessionActivity(activityIntent) 
        } else {
            Log.e(TAG, "Failed to create PendingIntent for launching the app UI. The notification might not open the app when clicked.")
        }

        mediaSession = mediaSessionBuilder.build()

        //
        //val notificationProvider = MediaNotificationProvider(this)
        //notificationProvider.radioPlayerService = this
        //setMediaNotificationProvider(notificationProvider)

        addSession(mediaSession!!)
    }

    ///
    fun play() {
        // Swiping the music player on the notification panel removes the media item.
        if (player.mediaItemCount == 0 && mediaItem != null) {
            player.setMediaItem(mediaItem!!)
            player.prepare()
        }

        player.playWhenReady = true
    }

    ///
    fun pause() {
        player.playWhenReady = false
    }

    ///
    fun stop() {
        player.playWhenReady = false
        player.stop()
    }

    /// Initializing the player with a new data.
    fun setMediaItem(title: String, url: String) {
        mediaItem = MediaItem.Builder()
            .setUri(url)
            .setMediaId(url) 
            .setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle(title)
                    .setMediaType(MediaMetadata.MEDIA_TYPE_RADIO_STATION)
                    .build()
            )
            .build()

        metadata = null
        defaultArtwork = null
        metadataArtwork = null
        defaultTitle = title

        player.setMediaItem(mediaItem!!, true)
        player.prepare()
    }

    /// Updates the player's metadata.
    fun setMetadata(newMetadata: ArrayList<String>) {
        metadata = newMetadata

        // Parse artwork from iTunes.
        if (itunesArtworkParser && metadata!![2].isEmpty())
           metadata!![2] = parseArtworkFromItunes(metadata!![0], metadata!![1])

        // Download artwork.
        metadataArtwork = downloadImage(metadata?.get(2))

        // Update metadata on the notification panel.
        //playerNotificationManager.invalidate()

        // Send the metadata to the Flutter side.
        val metadataIntent = Intent(ACTION_NEW_METADATA)
        metadataIntent.putStringArrayListExtra(ACTION_NEW_METADATA_EXTRA, metadata)
        localBroadcastManager.sendBroadcast(metadataIntent)
    }

    /// Sets the default artwork to display in the notification panel.
    fun setDefaultArtwork(image: Bitmap) {
        defaultArtwork = image
        //playerNotificationManager.invalidate()
    }

    /// Triggers on play or pause.
    override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
        super.onPlayWhenReadyChanged(playWhenReady, reason)

        // Notify the client.
        val stateIntent = Intent(ACTION_STATE_CHANGED)
        stateIntent.putExtra(ACTION_STATE_CHANGED_EXTRA, playWhenReady)
        localBroadcastManager.sendBroadcast(stateIntent)
    }

    /// Triggers when player state changes.
    override fun onPlaybackStateChanged(state: Int) {
        super.onPlaybackStateChanged(state)
        playbackState = state
    }

    override fun onPlayerError(error: PlaybackException) {
        super.onPlayerError(error)
        Log.e(TAG, "Player Error: ", error)
    }

    override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
        Log.d(TAG, "onMediaMetadataChanged")
        super.onMediaMetadataChanged(mediaMetadata)
    }

    /// Triggers when metadata comes from the stream.
    override fun onMetadata(rawMetadata: Metadata) {
        Log.d(TAG, "onMetadata")
        super.onMetadata(rawMetadata)

        if (ignoreIcy || rawMetadata[0] !is IcyInfo) return

        val icyInfo: IcyInfo = rawMetadata[0] as IcyInfo
        val title: String = icyInfo.title ?: return
        if (title.length == 0) return
        val cover: String = icyInfo.url ?: ""

        var newMetadata: MutableList<String> = title.split(" - ").toMutableList()
        if (newMetadata.lastIndex == 0) newMetadata.add("")
        newMetadata.add(cover)

        setMetadata(ArrayList(newMetadata))
    }

    /// Downloads an image from url and returns a Bitmap.
    fun downloadImage(value: String?): Bitmap? {
        if (value == null) return null
        var bitmap: Bitmap? = null

        try {
            val url: URL = URL(value)
            bitmap = runBlocking { 
                GlobalScope.async { 
                    BitmapFactory.decodeStream(url.openStream())
                }.await()
            }
        } catch (e: Throwable) {
            Log.e(TAG, e.toString())
        }

        return bitmap
    }

    /// Searches for an artwork by track name in iTunes.
    fun parseArtworkFromItunes(artist: String, track: String): String {
        var artwork: String = ""

        try {
            val term = URLEncoder.encode(artist + " - " + track, "utf-8") 

            val response = runBlocking { 
                GlobalScope.async { 
                    URL("https://itunes.apple.com/search?term=" + term + "&limit=1").readText()
                }.await()
            }

            val jsonObject = JSONObject(response)

            if (jsonObject.getInt("resultCount") > 0) {
                val artworkUrl30: String = jsonObject.getJSONArray("results").getJSONObject(0).getString("artworkUrl30")
                artwork = artworkUrl30.replace("30x30bb","500x500bb")
            }
        } catch (e: Throwable) {
            Log.e(TAG, e.toString())
        }

        return artwork
    }
}
