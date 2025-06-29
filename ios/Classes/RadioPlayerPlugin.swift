/*
 * RadioPlayerPlugin.swift
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import Flutter
import UIKit

/// The main plugin class for handling communication between Flutter and native iOS.
public class RadioPlayerPlugin: NSObject, FlutterPlugin {
    private lazy var player: RadioPlayerService = RadioPlayerService()
    private var remoteCommandStreamHandler: RemoteCommandStreamHandler?

    /// Registers the plugin with the Flutter engine.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = RadioPlayerPlugin()

        // Setup method channel for commands from Flutter.
        let channel = FlutterMethodChannel(name: "radio_player", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Setup event channel for player state updates.
        let playbackStateChannel = FlutterEventChannel(name: "radio_player/playbackStateEvents", binaryMessenger: registrar.messenger())
        playbackStateChannel.setStreamHandler(PlaybackStateStreamHandler(playerService: instance.player))

        // Setup event channel for metadata updates.
        let metadataChannel = FlutterEventChannel(name: "radio_player/metadataEvents", binaryMessenger: registrar.messenger())
        metadataChannel.setStreamHandler(MetadataStreamHandler(playerService: instance.player))

        // Setup event channel for remote command events (e.g., next/previous track).
        let remoteCommandChannel = FlutterEventChannel(name: "radio_player/remoteCommandEvents", binaryMessenger: registrar.messenger())
        instance.remoteCommandStreamHandler = RemoteCommandStreamHandler()
        remoteCommandChannel.setStreamHandler(instance.remoteCommandStreamHandler)
    }

    /// Handles method calls received from the Flutter side.
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            case "setStation":
                let args = call.arguments as! [String: Any]
                let title = args["title"] as! String
                let url = args["url"] as! String
                let imageData: Data? = (args["image_data"] as? FlutterStandardTypedData)?.data
                let parseStreamMetadata = args["parseStreamMetadata"] as! Bool
                let lookupOnlineArtwork = args["lookupOnlineArtwork"] as! Bool

                player.setStation(
                    title: title, 
                    url: url, 
                    imageData: imageData, 
                    parseStreamMetadata: parseStreamMetadata, 
                    lookupOnlineArtwork: lookupOnlineArtwork
                )
                result(nil)

            case "play":
                player.play()
                result(nil)

            case "pause":
                player.pause()
                result(nil)

            case "reset":
                player.reset()
                result(nil)

            case "setCustomMetadata":
                let args = call.arguments as! [String: String?]
                let artist = args["artist"] as? String
                let songTitle = args["title"] as? String
                let artworkUrl = args["artworkUrl"] as? String

                player.setMetadata(artist: artist, songTitle: songTitle, artworkUrl: artworkUrl)
                result(nil)

            case "setNavigationControls":
                guard let args = call.arguments as? [String: Bool],
                      let showNext = args["showNext"],
                      let showPrevious = args["showPrevious"] else {
                    result(nil)
                    return
                }
                player.setNavigationControls(showNext: showNext, showPrevious: showPrevious)
                result(nil)

            default:
                result(FlutterMethodNotImplemented)
        }
    }
}
