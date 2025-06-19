/*
 * RemoteCommandStreamHandler.swift
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import Flutter

/// Handles the event stream for remote command events to Flutter.
class RemoteCommandStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    static var shared: RemoteCommandStreamHandler?

    /// Initializes the handler and sets the shared instance for global access.
    override init() {
        super.init()
        RemoteCommandStreamHandler.shared = self
    }

    /// Called when Flutter starts listening to the event stream.
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    /// Called when Flutter stops listening to the event stream.
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    /// Relays remote command events to Flutter.
    func sendCommand(_ command: String) {
        self.eventSink?(command)
    }
}