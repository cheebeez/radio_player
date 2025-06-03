/*
 * PlaybackStateStreamHandler.swift
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import Flutter

/// Handles the event stream for player playback state updates to Flutter.
class PlaybackStateStreamHandler: NSObject, FlutterStreamHandler, RadioPlayerPlaybackStateDelegate {
    private var eventSink: FlutterEventSink?
    private var previousPlaybackState: String?
    private weak var playerService: RadioPlayerService?

    /// Initializes the stream handler with a player service instance.
    init(playerService: RadioPlayerService) {
        self.playerService = playerService
        super.init()
    }

    /// Called when Flutter starts listening to the event stream.
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        playerService?.playbackStateDelegate = self
        return nil
    }

    /// Relays player state changes from the player service to Flutter.
    func radioPlayerDidChangePlaybackState(playbackState: String) {
            if previousPlaybackState != playbackState {
                previousPlaybackState = playbackState
                self.eventSink?(playbackState)
            }
    }

    /// Called when Flutter stops listening to the event stream.
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil

        if playerService?.playbackStateDelegate === self {
            playerService?.playbackStateDelegate = nil
        }

        return nil
    }
}

