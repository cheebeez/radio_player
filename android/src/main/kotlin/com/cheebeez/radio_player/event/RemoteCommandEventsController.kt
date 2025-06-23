/*
 * RemoteCommandEventsController.kt
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

package com.cheebeez.radio_player

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/// Manages the EventChannel for remote command events using a singleton pattern.
object RemoteCommandEventsController : EventChannel.StreamHandler {
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    /// Attaches the event channel to the Flutter plugin's binary messenger.
    fun attach(messenger: BinaryMessenger) {
        if (eventChannel != null) return
        eventChannel = EventChannel(messenger, "radio_player/remoteCommandEvents")
        eventChannel?.setStreamHandler(this)
    }

    /// Detaches the event channel and cleans up resources.
    fun detach() {
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null
    }

    /// Called when Flutter starts listening to the event stream.
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    /// Called when Flutter stops listening to the event stream.
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    /// Sends a command to Flutter, ensuring it's called on the main thread.
    fun sendCommand(command: String) {
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(command)
        }
    }
}