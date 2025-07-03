/*
 * radio_player.dart
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:radio_player/models/metadata.dart';
import 'package:radio_player/models/playback_state.dart';
import 'package:radio_player/models/remote_command.dart';

export 'package:radio_player/models/metadata.dart';
export 'package:radio_player/models/playback_state.dart';
export 'package:radio_player/models/remote_command.dart';

class RadioPlayer {
  RadioPlayer._internal();

  static const _methodChannel = MethodChannel('radio_player');
  static const _metadataEvents = EventChannel('radio_player/metadataEvents');
  static const _playbackStateEvents = EventChannel(
    'radio_player/playbackStateEvents',
  );
  static const _remoteCommandEvents = EventChannel(
    'radio_player/remoteCommandEvents',
  );

  static Stream<PlaybackState>? _playbackStateStream;
  static Stream<Metadata>? _metadataStream;
  static Stream<RemoteCommand>? _remoteCommandStream;

  /// Sets the radio station with title, URL, and optional artwork.
  static Future<void> setStation({
    required String title,
    required String url,
    String? logoAssetPath,
    String? logoNetworkUrl,
    bool parseStreamMetadata = true,
    bool lookupOnlineArtwork = false,
  }) async {
    Uint8List? imageData;

    // Attempt to load logo from local asset path if provided.
    if (logoAssetPath != null) {
      final byteData = await rootBundle.load(logoAssetPath);
      imageData = byteData.buffer.asUint8List();
    }
    // Else, attempt to load logo from network URL if provided.
    else if (logoNetworkUrl != null) {
      final byteData = await NetworkAssetBundle(
        Uri.parse(logoNetworkUrl),
      ).load(logoNetworkUrl);
      imageData = byteData.buffer.asUint8List();
    }

    await _methodChannel.invokeMethod('setStation', <String, dynamic>{
      'title': title,
      'url': url,
      'image_data': imageData,
      'parseStreamMetadata': parseStreamMetadata,
      'lookupOnlineArtwork': lookupOnlineArtwork,
    });
  }

  /// Starts or resumes playback.
  static Future<void> play() async {
    await _methodChannel.invokeMethod('play');
  }

  /// Pauses playback.
  static Future<void> pause() async {
    await _methodChannel.invokeMethod('pause');
  }

  /// Stops playback, removes notification, readies player for a new station.
  static Future<void> reset() async {
    await _methodChannel.invokeMethod('reset');
  }

  /// Stops playback.
  static Future<void> stop() async {
    await _methodChannel.invokeMethod('stop');
  }

  /// Sets custom metadata for the current stream.
  static Future<void> setCustomMetadata({
    String? artist,
    String? title,
    String? artworkUrl,
  }) async {
    Map<String, String?> metadataMap = {
      'artist': artist,
      'title': title,
      'artworkUrl': artworkUrl,
    };

    await _methodChannel.invokeMethod('setCustomMetadata', metadataMap);
  }

  /// Sets the visibility of the next and previous track controls.
  static Future<void> setNavigationControls({
    required bool showNextButton,
    required bool showPreviousButton,
  }) async {
    await _methodChannel.invokeMethod('setNavigationControls', {
      'showNext': showNextButton,
      'showPrevious': showPreviousButton,
    });
  }

  /// A stream indicating the playback state.
  static Stream<PlaybackState> get playbackStateStream {
    _playbackStateStream ??= _playbackStateEvents
        .receiveBroadcastStream()
        .map<PlaybackState>(
          (event) => PlaybackState.fromString(event as String),
        );
    return _playbackStateStream!;
  }

  /// A stream of metadata updates from the radio stream.
  static Stream<Metadata> get metadataStream {
    _metadataStream ??= _metadataEvents.receiveBroadcastStream().map((value) {
      return Metadata.fromMap(value as Map<dynamic, dynamic>);
    });

    return _metadataStream!;
  }

  /// A stream for remote control commands like "nextTrack" or "previousTrack".
  static Stream<RemoteCommand> get remoteCommandStream {
    _remoteCommandStream ??= _remoteCommandEvents.receiveBroadcastStream().map(
      (event) => RemoteCommand.fromString(event as String?),
    );
    return _remoteCommandStream!;
  }
}
