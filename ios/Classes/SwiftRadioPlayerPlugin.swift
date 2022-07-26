/*
 *  SwiftRadioPlayerPlugin.swift
 *
 *  Created by Ilya Chirkunov <xc@yar.net> on 10.01.2021.
 */

import Flutter
import UIKit

public class SwiftRadioPlayerPlugin: NSObject, FlutterPlugin {
    static let instance = SwiftRadioPlayerPlugin()
    private let player = RadioPlayer()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "radio_player", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)

        let stateChannel = FlutterEventChannel(name: "radio_player/stateEvents", binaryMessenger: registrar.messenger())
        stateChannel.setStreamHandler(StateStreamHandler())
        let metadataChannel = FlutterEventChannel(name: "radio_player/metadataEvents", binaryMessenger: registrar.messenger())
        metadataChannel.setStreamHandler(MetadataStreamHandler())

        // Channel for default artwork
        let defaultArtworkChannel = FlutterBasicMessageChannel(name: "radio_player/setArtwork", binaryMessenger: registrar.messenger(), codec: FlutterBinaryCodec())
        defaultArtworkChannel.setMessageHandler { message, result in
            let image = UIImage(data: message as! Data)
            instance.player.defaultArtwork = image
            instance.player.setArtwork(image)
            result(nil)
        }

        // Channel for metadata artwork
        let metadataArtworkChannel = FlutterBasicMessageChannel(name: "radio_player/getArtwork", binaryMessenger: registrar.messenger(), codec: FlutterBinaryCodec())
        metadataArtworkChannel.setMessageHandler { message, result in
            let data = instance.player.metadataArtwork?.jpegData(compressionQuality: 1.0)
            result(data)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
            case "set":
                let args = call.arguments as! Array<String>
                player.setMediaItem(args[0], args[1])
            case "play":
                player.play()
            case "stop":
                player.stop()
            case "pause":
                player.pause()
            case "metadata":
                let metadata = call.arguments as! Array<String>
                player.setMetadata(metadata)
            case "itunes_artwork_parser":
                let enable = call.arguments as! Bool
                player.itunesArtworkParser = enable
            case "ignore_icy":
                player.ignoreIcy = true
            default:
                result(FlutterMethodNotImplemented)
        }
 
        result(1)
    }
}

/** Handler for playback state changes, passed to setStreamHandler() */
class StateStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var previousState: Bool?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        NotificationCenter.default.addObserver(self, selector: #selector(onRecieve(_:)), name: NSNotification.Name(rawValue: "state"), object: nil)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // Notification receiver for playback state changes, passed to addObserver()
    @objc private func onRecieve(_ notification: Notification) {
        if let state = notification.userInfo!["state"], previousState != (state as! Bool) {
            previousState = state as? Bool
            eventSink?(state)
        }
    }
}

/** Handler for new metadata, passed to setStreamHandler() */
class MetadataStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        NotificationCenter.default.addObserver(self, selector: #selector(onRecieve(_:)), name: NSNotification.Name(rawValue: "metadata"), object: nil)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    // Notification receiver for new metadata, passed to addObserver()
    @objc private func onRecieve(_ notification: Notification) {
        if let metadata = notification.userInfo!["metadata"] {
            eventSink?(metadata)
        }
    }
}
