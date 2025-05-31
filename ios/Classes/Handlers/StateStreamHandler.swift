/*
 * StateStreamHandler.swift
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import Flutter

/// Handles the event stream for player state updates to Flutter.
class StateStreamHandler: NSObject, FlutterStreamHandler, RadioPlayerStateDelegate {
    private var eventSink: FlutterEventSink?
    private var previousState: Bool?
    private weak var playerService: RadioPlayerService?

    /// Initializes the stream handler with a player service instance.
    init(playerService: RadioPlayerService) {
        self.playerService = playerService
        super.init()
    }

    /// Called when Flutter starts listening to the event stream.
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        playerService?.stateDelegate = self
        return nil
    }

    /// Relays player state changes from the player service to Flutter.
    func radioPlayerDidChangeState(isPlaying: Bool) {
        if previousState != isPlaying {
            previousState = isPlaying
            self.eventSink?(isPlaying)
        }
    }

    /// Called when Flutter stops listening to the event stream.
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil

        if playerService?.stateDelegate === self {
            playerService?.stateDelegate = nil
        }

        return nil
    }
}

