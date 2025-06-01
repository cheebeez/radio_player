/*
 * MetadataStreamHandler.swift
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import Flutter

/// Handles the event stream for player metadata updates to Flutter.
class MetadataStreamHandler: NSObject, FlutterStreamHandler, RadioPlayerMetadataDelegate {
    private var eventSink: FlutterEventSink?
    private weak var playerService: RadioPlayerService?

    /// Initializes the stream handler with a player service instance.
    init(playerService: RadioPlayerService) {
        self.playerService = playerService
        super.init()
    }

    /// Called when Flutter starts listening to the event stream.
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        playerService?.metadataDelegate = self
        return nil
    }

    /// Relays metadata updates from the player service to Flutter.
    func radioPlayerDidUpdateMetadata(artist: String?, title: String?, artworkUrl: String?, artworkData: Data?) {
        let metadata: [String: Any?] = [
            "artist": artist,
            "title": title,
            "artworkUrl": artworkUrl,
            "artworkData": artworkData
        ]

        DispatchQueue.main.async {
            self.eventSink?(metadata)
        }
    }

    /// Called when Flutter stops listening to the event stream.
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil

        if playerService?.metadataDelegate === self {
             playerService?.metadataDelegate = nil
        }

        return nil
    }

}