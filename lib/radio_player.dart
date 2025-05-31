/*
 * radio_player.dart
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RadioPlayer {
  static const _methodChannel = MethodChannel('radio_player');
  static const _metadataEvents = EventChannel('radio_player/metadataEvents');
  static const _stateEvents = EventChannel('radio_player/stateEvents');

  Stream<bool>? _stateStream;
  Stream<List<String>>? _metadataStream;
  Uint8List? artworkData;

  /// Set new streaming URL.
  Future<void> setChannel({
    required String title,
    required String url,
    String? imagePath,
    //bool useIcyMetadata = true,
    //bool enableOnlineArtworkLookup = false,
  }) async {
    Uint8List? imageData;
    artworkData = null;

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
  Future<void> setCustomMetadata(List<String> metadata) async {
    Map<String, String> metadataMap = {
      'artist': metadata[0],
      'title': metadata[1],
      'artworkUrl': metadata[2],
    };

    await _methodChannel.invokeMethod('setCustomMetadata', metadataMap);
  }

  /// Returns the album cover if it has already been downloaded.
  Future<Image?> getArtworkImage() async {
    Image? image;

    if (artworkData != null) {
      image = Image.memory(artworkData!, key: UniqueKey(), fit: BoxFit.cover);
    }

    return image;
  }

  /// Get the playback state stream.
  Stream<bool> get stateStream {
    _stateStream ??= _stateEvents.receiveBroadcastStream().map<bool>(
      (value) => value,
    );

    return _stateStream!;
  }

  /// Get the metadata stream.
  Stream<List<String>> get metadataStream {
    _metadataStream ??= _metadataEvents.receiveBroadcastStream().map((rawMap) {
      if (rawMap.containsKey('artworkData') && rawMap['artworkData'] != null) {
        artworkData = rawMap['artworkData'] as Uint8List?;
      } else {
        artworkData = null;
      }

      return [rawMap['artist'], rawMap['title'], rawMap['artworkUrl']];
    });

    return _metadataStream!;
  }
}
