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

    /// Registers the plugin with the Flutter engine.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = RadioPlayerPlugin()

        // Setup method channel for commands from Flutter.
        let channel = FlutterMethodChannel(name: "radio_player", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Setup event channel for player state updates.
        let stateChannel = FlutterEventChannel(name: "radio_player/stateEvents", binaryMessenger: registrar.messenger())
        stateChannel.setStreamHandler(StateStreamHandler(playerService: instance.player))

        // Setup event channel for metadata updates.
        let metadataChannel = FlutterEventChannel(name: "radio_player/metadataEvents", binaryMessenger: registrar.messenger())
        metadataChannel.setStreamHandler(MetadataStreamHandler(playerService: instance.player))
    }

    /// Handles method calls received from the Flutter side.
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            case "setStation":
                let args = call.arguments as! [String: Any]
                let title = args["title"] as! String
                let url = args["url"] as! String
                let imageData: Data? = (args["image_data"] as? FlutterStandardTypedData)?.data

                player.setMediaItem(title: title, url: url, imageData: imageData)
                result(nil)
            case "play":
                player.play()
                result(nil)
            case "pause":
                player.pause()
                result(nil)
            case "stop":
                player.stop()
                result(nil)
            case "setCustomMetadata":
                let args = call.arguments as! [String: String?]
                let artist = args["artist"] as? String ?? ""
                let songTitle = args["title"] as? String ?? ""
                let artworkUrl = args["artworkUrl"] as? String ?? ""

                player.setMetadata(artist: artist, songTitle: songTitle, artworkUrl: artworkUrl)
                result(nil)

            case "setItunesArtworkParsing":
                player.itunesArtworkParser = call.arguments as! Bool
                result(nil)
            case "setIgnoreIcyMetadata":
                player.ignoreIcy = call.arguments as! Bool
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
        }
    }
}
