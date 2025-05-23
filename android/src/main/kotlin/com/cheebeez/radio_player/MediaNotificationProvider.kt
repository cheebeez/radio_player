/*
 *  MediaNotificationProvider.kt
 *
 *  Created by Ilia Chirkunov <contact@cheebeez.com> on 21.05.2025.
 */
 
package com.cheebeez.radio_player

import com.cheebeez.radio_player.R
import android.os.Bundle
import android.os.Build
import android.app.Notification
import android.content.Context
import androidx.core.app.NotificationCompat 
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaNotification
import androidx.media3.session.CommandButton
import androidx.media3.common.MediaMetadata
import com.google.common.collect.ImmutableList

import androidx.media3.session.MediaStyleNotificationHelper

class MediaNotificationProvider(val context: Context) : MediaNotification.Provider {
    var radioPlayerService: RadioPlayerService? = null

    override fun createNotification(
        mediaSession: MediaSession,
        customLayout: ImmutableList<CommandButton>,
        actionFactory: MediaNotification.ActionFactory,
        onNotificationChangedCallback: MediaNotification.Provider.Callback
    ): MediaNotification {
        val player = mediaSession.player
        val metadata = player.currentMediaItem?.mediaMetadata ?: MediaMetadata.EMPTY

        val builder = NotificationCompat.Builder(context, RadioPlayerService.NOTIFICATION_CHANNEL_ID)
            //.setContentTitle(metadata.title ?: "title")
            //.setContentText(metadata.artist ?: "artist")
            .setSmallIcon(R.drawable.notification_icon)
            //.setLargeIcon(largeIconBitmap)
            //.setContentIntent(mediaSession.sessionActivity)
            //.setDeleteIntent(actionFactory.createMediaActionPendingIntent(mediaSession, androidx.media3.common.Player.COMMAND_STOP))
            //.setOngoing(player.playWhenReady) // Уведомление нельзя будет смахнуть, если плеер активен (опционально)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setStyle(MediaStyleNotificationHelper.MediaStyle(mediaSession))
 

        createNotificationChannel()

        return MediaNotification(RadioPlayerService.NOTIFICATION_ID, builder.build())
    }

    override fun handleCustomCommand(session: MediaSession, action: String, extras: Bundle): Boolean {
        return false
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                RadioPlayerService.NOTIFICATION_CHANNEL_ID,
                context.getString(R.string.channel_name),
                android.app.NotificationManager.IMPORTANCE_HIGH
            )
            // channel.description = "Radio Player Channel" // опционально

            val notificationManager = context.getSystemService(android.app.NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
