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

export 'package:radio_player/models/metadata.dart';

class RadioPlayer {
  static const _methodChannel = MethodChannel('radio_player');
  static const _metadataEvents = EventChannel('radio_player/metadataEvents');
  static const _stateEvents = EventChannel('radio_player/stateEvents');

  Stream<bool>? _stateStream;
  Stream<Metadata>? _metadataStream;

  /// Set new streaming URL.
  Future<void> setChannel({
    required String title,
    required String url,
    String? imagePath,
    //bool useIcyMetadata = true,
    //bool enableOnlineArtworkLookup = false,
  }) async {
    Uint8List? imageData;

    if (imagePath != null) {
      final byteData =
          imagePath.startsWith('http')
              ? await NetworkAssetBundle(Uri.parse(imagePath)).load(imagePath)
              : await rootBundle.load(imagePath);

      imageData = byteData.buffer.asUint8List();
    }

    await _methodChannel.invokeMethod('setStation', <String, dynamic>{
      'title': title,
      'url': url,
      'image_data': imageData,
    });
  }

  Future<void> play() async {
    await _methodChannel.invokeMethod('play');
  }

  Future<void> stop() async {
    await _methodChannel.invokeMethod('stop');
  }

  Future<void> pause() async {
    await _methodChannel.invokeMethod('pause');
  }

  /// Helps avoid conflicts with custom metadata.
  Future<void> ignoreIcyMetadata([bool ignoreIcy = true]) async {
    await _methodChannel.invokeMethod('setIgnoreIcyMetadata', ignoreIcy);
  }

  /// Parse album covers from iTunes.
  Future<void> itunesArtworkParser(bool enable) async {
    await _methodChannel.invokeMethod('setItunesArtworkParsing', enable);
  }

  /// Set custom metadata.
  Future<void> setCustomMetadata(
    String? artist,
    String? title,
    String? artworkUrl,
  ) async {
    Map<String, String?> metadataMap = {
      'artist': artist,
      'title': title,
      'artworkUrl': artworkUrl,
    };

    await _methodChannel.invokeMethod('setCustomMetadata', metadataMap);
  }

  /// Get the playback state stream.
  Stream<bool> get stateStream {
    _stateStream ??= _stateEvents.receiveBroadcastStream().map<bool>(
      (value) => value,
    );

    return _stateStream!;
  }

  /// Get the metadata stream.
  Stream<Metadata> get metadataStream {
    _metadataStream ??= _metadataEvents.receiveBroadcastStream().map((value) {
      return Metadata.fromMap(value as Map<dynamic, dynamic>);
    });

    return _metadataStream!;
  }
}
