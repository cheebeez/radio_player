/*
 * PlaybackStateEventsController.kt
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

package com.cheebeez.radio_player

import androidx.media3.common.Player
import androidx.media3.session.MediaController
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/// Manages the EventChannel for player state events.
class PlaybackStateEventsController : EventChannelController, Player.Listener {
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var mediaController: MediaController? = null
    private var previousStateString: String? = null

    // Called when the player's readiness to play or its intention to play changes.
    override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
        updateAndSendPlaybackState()
    }

    // Called when the main state of the player changes (buffering, ready, idle, ended).
    override fun onPlaybackStateChanged(playbackState: Int) {
        updateAndSendPlaybackState()
    }

    // Helper method to determine and send the current state.
    private fun updateAndSendPlaybackState() {
        val controller = mediaController ?: return
        if (eventSink == null) return

        val currentPlayWhenReady = controller.playWhenReady
        val currentPlaybackState = controller.playbackState

        val newStateString = when (currentPlaybackState) {
            Player.STATE_BUFFERING -> "buffering"
            Player.STATE_READY -> if (currentPlayWhenReady) "playing" else "paused"
            Player.STATE_IDLE -> "paused" 
            Player.STATE_ENDED -> "paused"
            else -> "unknown"
        }

        // Send the playback state only if it has changed since the last time it was sent.
        if (newStateString != previousStateString) {
            eventSink?.success(newStateString)
            previousStateString = newStateString
        }
    }

    /// Attaches the event channel to the Flutter plugin's binary messenger.
    override fun attach(messenger: BinaryMessenger) {
        eventChannel = EventChannel(messenger, "radio_player/playbackStateEvents")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                eventSink = events

                if (mediaController != null) {
                    mediaController?.addListener(this@PlaybackStateEventsController)
                }
            }

            override fun onCancel(arguments: Any?) {
                mediaController?.removeListener(this@PlaybackStateEventsController)
                eventSink = null
            }
        })
    }

    /// Sets or updates the MediaController instance and re-registers listeners.
    override fun setMediaController(controller: MediaController?) {
        this.mediaController?.removeListener(this@PlaybackStateEventsController)
        this.mediaController = controller

        if (eventSink != null && mediaController != null) {
            this.mediaController?.addListener(this@PlaybackStateEventsController)
        }
    }

    /// Detaches the event channel and cleans up resources.
    override fun detach() {
        eventChannel.setStreamHandler(null)
        mediaController = null
    }
}
