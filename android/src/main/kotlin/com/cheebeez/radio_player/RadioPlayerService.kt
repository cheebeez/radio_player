/*
 *  RadioPlayerService.kt
 *
 *  Created by Ilia Chirkunov <xc@yar.net> on 30.12.2020.
 */

package com.cheebeez.radio_player

import java.net.URL
import java.net.URLEncoder
import org.json.JSONObject
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.MediaMetadataCompat
import android.app.Service
import android.app.PendingIntent
import android.content.Intent
import android.content.Context
import android.os.IBinder
import android.os.Binder
import android.app.Notification
import android.content.ComponentName
import android.content.ServiceConnection
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.Player
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.audio.AudioAttributes
import com.google.android.exoplayer2.C
import com.google.android.exoplayer2.metadata.Metadata
import com.google.android.exoplayer2.metadata.icy.IcyInfo
import com.google.android.exoplayer2.ext.mediasession.MediaSessionConnector
import com.google.android.exoplayer2.ui.PlayerNotificationManager
import com.google.android.exoplayer2.ui.PlayerNotificationManager.BitmapCallback
import com.google.android.exoplayer2.ui.PlayerNotificationManager.MediaDescriptionAdapter
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import java.util.*
import java.util.concurrent.TimeUnit
import kotlin.collections.ArrayList

/** Service for plays streaming audio content using ExoPlayer. */
class RadioPlayerService : Service(), Player.Listener {

    companion object {
        const val NOTIFICATION_CHANNEL_ID = "radio_channel_id"
        const val NOTIFICATION_ID = 1
        const val ACTION_STATE_CHANGED = "state_changed"
        const val ACTION_STATE_CHANGED_EXTRA = "state"
        const val ACTION_NEW_METADATA = "matadata_changed"
        const val ACTION_NEW_METADATA_EXTRA = "matadata"
    }

    var metadataArtwork: Bitmap? = null
    var ignoreIcy: Boolean = false
    var itunesArtworkParser: Boolean = false
    lateinit var context: Context
    private lateinit var mediaItems: List<MediaItem>
    private var defaultArtwork: Bitmap? = null
    private var playerNotificationManager: PlayerNotificationManager? = null
    private var mediaSession: MediaSessionCompat? = null
    private var notificationTitle = ""
    private var isForegroundService = false
    private var metadata: ArrayList<String>? = null
    private var localBinder = LocalBinder()
    private var playbackState = Player.STATE_IDLE
    private val player: ExoPlayer by lazy {
        ExoPlayer.Builder(this).build()
    }
    private val localBroadcastManager: LocalBroadcastManager by lazy {
        LocalBroadcastManager.getInstance(this)
    }

    private var workManager = WorkManager.getInstance(this)
    private lateinit var stopPlayerJobId: UUID

    private var lastPlayedStreamTitle: String? = null
    private var lastPlayedStreamUrl: String? = null

    inner class LocalBinder : Binder() {
        // Return this instance of RadioPlayerService so clients can call public methods.
        fun getService(): RadioPlayerService = this@RadioPlayerService
    }

    override fun onBind(intent: Intent?): IBinder? {
        return localBinder
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        player.setRepeatMode(Player.REPEAT_MODE_ONE)
        player.addListener(this)

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaSession?.release()
        playerNotificationManager?.setPlayer(null)
        player.release()
        android.os.Process.killProcess(android.os.Process.myPid());
    }

    fun play() {
        // Swiping the music player on the notification panel removes the media item.
        if (player.getMediaItemCount() == 0) player.addMediaItems(mediaItems)

        player.playWhenReady = true
    }

    fun stop() {
        player.playWhenReady = false
        player.stop()
    }

    fun pause() {
        player.playWhenReady = false
    }

    /** Initializing the player with a new data. */
    fun setMediaItem(streamTitle: String, streamUrl: String) {
        lastPlayedStreamTitle = streamTitle
        lastPlayedStreamUrl = streamUrl

        mediaItems = runBlocking { 
                GlobalScope.async { 
                    parseUrls(streamUrl).map { MediaItem.fromUri(it) }
                }.await() 
            }

        metadata = null
        defaultArtwork = null
        metadataArtwork = null
        notificationTitle = streamTitle
        playerNotificationManager?.invalidate() ?: createNotificationManager()

        player.stop()
        player.clearMediaItems()
        player.seekTo(0)
        player.addMediaItems(mediaItems)
    }

    /** Updates the player's metadata. */
    fun setMetadata(newMetadata: ArrayList<String>) {
        metadata = newMetadata

        // Parse artwork from iTunes.
        if (itunesArtworkParser && metadata!![2].isEmpty())
           metadata!![2] = parseArtworkFromItunes(metadata!![0], metadata!![1])

        // Download artwork.
        metadataArtwork = downloadImage(metadata?.get(2))

        // Update metadata on the notification panel.
        // playerNotificationManager?.invalidate()
        val mdc = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, metadata?.get(1) ?: "")
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, metadata?.get(0) ?: notificationTitle)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, metadata?.get(1) ?: "")
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, metadata?.get(0) ?: notificationTitle)
            .putBitmap(MediaMetadataCompat.METADATA_KEY_ART, metadataArtwork ?: defaultArtwork)
            .build()
        mediaSession?.setMetadata(mdc)

        // Send the metadata to the Flutter side.
        val metadataIntent = Intent(ACTION_NEW_METADATA)
        metadataIntent.putStringArrayListExtra(ACTION_NEW_METADATA_EXTRA, metadata)
        localBroadcastManager.sendBroadcast(metadataIntent)
    }

    /** Sets the default artwork to display in the notification panel. */
    fun setDefaultArtwork(image: Bitmap) {
        defaultArtwork = image
        playerNotificationManager?.invalidate()
    }

    /** Resumes last played track and player notification on the system tray **/
    fun addToControlCenter() {
        if(lastPlayedStreamTitle != null && lastPlayedStreamUrl != null) {
            setMediaItem(lastPlayedStreamTitle!!, lastPlayedStreamUrl!!)
            play()
        }
    }

    /** Stops last played track and removes player notification from the system tray **/
    fun removeFromControlCenter() {
        player.stop()
        player.clearMediaItems()
        player.seekTo(0)

        mediaSession?.setMetadata(null)
        playerNotificationManager?.invalidate()
        stop()
    }

    /** Start timer job for delayed player stop **/
    fun startTimer(timerDuration: Double) {
        val countDownInterval = timerDuration.toLong() * 1000
        stopPlayerJobId = UUID.randomUUID()
        val stopPlayerJob = OneTimeWorkRequestBuilder<StopPlayerJob>()
            .setInitialDelay(countDownInterval, TimeUnit.MILLISECONDS)
            .setId(stopPlayerJobId)
            .build()
        workManager.beginWith(stopPlayerJob).enqueue()
    }

    /** Cancel timer job for delayed player stop **/
    fun cancelTimer() {
        workManager.cancelWorkById(stopPlayerJobId)
    }

    /** Creates a notification manager for background playback. */
    private fun createNotificationManager() {
        // Setup media session
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON)
        val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
        mediaSession = MediaSessionCompat(context, "RadioPlayerService", null, pendingIntent)

        mediaSession?.let {
            it.isActive = true
            val mediaSessionConnector = MediaSessionConnector(it)
            mediaSessionConnector.setPlayer(player)
        }

        // Setup audio focus
        val audioAttributes: AudioAttributes = AudioAttributes.Builder()
            .setUsage(C.USAGE_MEDIA)
            .setContentType(C.CONTENT_TYPE_MUSIC)
            .build()

        player.setAudioAttributes(audioAttributes, true);

        // Setup notification manager.
        val mediaDescriptionAdapter = object : MediaDescriptionAdapter {
            override fun createCurrentContentIntent(player: Player): PendingIntent? {
                val notificationIntent = Intent()
                notificationIntent.setClassName(context.packageName, "${context.packageName}.MainActivity")
                return PendingIntent.getActivity(context, 0, notificationIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            }
            override fun getCurrentLargeIcon(player: Player, callback: BitmapCallback): Bitmap? {
                return metadataArtwork ?: defaultArtwork;
            }
            override fun getCurrentContentTitle(player: Player): String {
                return metadata?.get(0) ?: notificationTitle
            }
            override fun getCurrentContentText(player: Player): String? {
                return metadata?.get(1)
            }
        }

        val notificationListener = object : PlayerNotificationManager.NotificationListener {
            override fun onNotificationPosted(notificationId: Int, notification: Notification, ongoing: Boolean) {
                if(ongoing && !isForegroundService) {
                    startForeground(notificationId, notification)
                    isForegroundService = true
                }
            }
            override fun onNotificationCancelled(notificationId: Int, dismissedByUser: Boolean) {
                stopForeground(true)
                isForegroundService = false
                stopSelf()
            }
        }

        playerNotificationManager = PlayerNotificationManager.Builder(
            this, NOTIFICATION_ID, NOTIFICATION_CHANNEL_ID)
            .setChannelNameResourceId(R.string.channel_name)
            .setMediaDescriptionAdapter(mediaDescriptionAdapter)
            .setNotificationListener(notificationListener)
            .build().apply {
                setUsePlayPauseActions(true)
                setUseFastForwardAction(false)
                setUseRewindAction(false)
                setUsePreviousAction(false)
                setUseNextAction(false)
                setPlayer(player)
                mediaSession?.let { setMediaSessionToken(it.sessionToken) }
            }
    }

    /** Triggers on play or pause. */
    override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
        super.onPlayWhenReadyChanged(playWhenReady, reason)

        if (playbackState == Player.STATE_IDLE && playWhenReady == true) {
            player.prepare()
        }

        // Notify the client.
        val stateIntent = Intent(ACTION_STATE_CHANGED)
        stateIntent.putExtra(ACTION_STATE_CHANGED_EXTRA, playWhenReady)
        localBroadcastManager.sendBroadcast(stateIntent)

        if (!playWhenReady && playbackState == Player.STATE_READY) {
            stop()
        }
    }

    /** Triggers when player state changes. */
    override fun onPlaybackStateChanged(state: Int) {
        super.onPlaybackStateChanged(state)
        playbackState = state
    }

    /** Triggers when metadata comes from the stream. */
    override fun onMetadata(rawMetadata: Metadata) {
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

    /** Downloads an image from url and returns a Bitmap. */
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
            println(e)
        }

        return bitmap
    }

    /** Searches for an artwork by track name in iTunes. */
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
            println(e)
        }

        return artwork
    }

    /** Extract URLs from user link. */
    private fun parseUrls(url: String): List<String> {
        var urls: List<String> = emptyList()

        when (url.substringAfterLast(".")) {
            "pls" -> {
                 urls = URL(url).readText().lines().filter { 
                    it.contains("=http") }.map {
                        it.substringAfter("=")
                    }
            }
            "m3u" -> {
                val content = URL(url).readText().trim()
                 urls = listOf<String>(content)
            }
            else -> {
                urls = listOf<String>(url)
            }
        }

        return urls
    }

    class StopPlayerJob(private val ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
        override fun doWork(): Result {
            val connection = object : ServiceConnection {
                override fun onServiceConnected(className: ComponentName, service: IBinder) {
                    val binder = service as RadioPlayerService.LocalBinder
                    val radioPlayerService = binder.getService()
                    radioPlayerService.stop()
                }

                override fun onServiceDisconnected(arg0: ComponentName) {}
            }
            ctx.bindService(Intent(ctx, RadioPlayerService::class.java), connection, Context.BIND_AUTO_CREATE)
            return Result.success()
        }
    }
}
