/*
 * MetadataEventsController.kt
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

package com.cheebeez.radio_player

import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/// Manages the EventChannel for player metadata events.
class MetadataEventsController : EventChannelController, Player.Listener {
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var mediaController: MediaController? = null

    /// Called when the media metadata changes.
    override fun onMediaMetadataChanged(mediaMetadata: MediaMetadata) {
        // Skip initial metadata that is set during setStation.
        if (mediaMetadata.extras?.getBoolean(RadioPlayerService.METADATA_EXTRA_IS_INITIAL, false) == true) {
            return
        }

        val metadataMap = mapOf(
            "artist" to (mediaMetadata.artist?.toString() ?: ""),
            "title" to (mediaMetadata.title?.toString() ?: ""),
            "artworkUrl" to (mediaMetadata.artworkUri?.toString() ?: ""),
            "artworkData" to mediaMetadata.artworkData
        )
        eventSink?.success(metadataMap)
    }

    /// Attaches the event channel to the Flutter plugin's binary messenger.
    override fun attach(messenger: BinaryMessenger) {
        eventChannel = EventChannel(messenger, "radio_player/metadataEvents")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                mediaController?.removeListener(this@MetadataEventsController)
                eventSink = null
            }
        })
    }

    /// Sets or updates the MediaController instance and re-registers listeners.
    override fun setMediaController(controller: MediaController?) {
        this.mediaController?.removeListener(this@MetadataEventsController)
        this.mediaController = controller
        
        if (eventSink != null) {
            this.mediaController?.addListener(this@MetadataEventsController)
        }
    }

    /// Detaches the event channel and cleans up resources.
    override fun detach() {
        eventChannel.setStreamHandler(null)
        mediaController?.removeListener(this@MetadataEventsController)
        eventSink = null
        mediaController = null
    }
}