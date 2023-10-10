/*
 *  radio_player.dart
 *
 *  Created by Ilia Chirkunov <xc@yar.net> on 28.12.2020.
 */

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RadioPlayer {
  static const _methodChannel = MethodChannel('radio_player');
  static const _metadataEvents = EventChannel('radio_player/metadataEvents');
  static const _stateEvents = EventChannel('radio_player/stateEvents');

  static const _defaultArtworkChannel = BasicMessageChannel("radio_player/setArtwork", BinaryCodec());
  static const _metadataArtworkChannel = BasicMessageChannel("radio_player/getArtwork", BinaryCodec());

  Stream<bool>? _stateStream;
  Stream<List<String>>? _metadataStream;

  /// Set new streaming URL.
  Future<void> setChannel({required String title, required String url, String? imagePath}) async {
    await Future.delayed(Duration(milliseconds: 500));
    await _methodChannel.invokeMethod('set', [title, url]);

    if (imagePath != null) setDefaultArtwork(imagePath);
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

  /// Added media info to player in control center and enable buttons on it
  Future<void> addToControlCenter() async {
    await _methodChannel.invokeMethod('addToControlCenter');
  }

  /// Remove media info from player in control center and disable any interaction with it
  Future<void> removeFromControlCenter() async {
    await _methodChannel.invokeMethod('removeFromControlCenter');
  }

  /// Stop playing after specified number of seconds.
  Future<void> setupTimer(Duration duration) async {
    return await _methodChannel.invokeMethod('startTimer', duration.inSeconds);
  }

  /// Cancel scheduled timer
  Future<void> removeTimer() async {
    return await _methodChannel.invokeMethod('cancelTimer');
  }

  /// Set the default image in the notification panel
  Future<void> setDefaultArtwork(String image) async {
    final byteData = image.startsWith('http')
        ? await NetworkAssetBundle(Uri.parse(image)).load(image)
        : await rootBundle.load(image);
    _defaultArtworkChannel.send(byteData);
  }

  /// Helps avoid conflicts with custom metadata.
  Future<void> ignoreIcyMetadata() async {
    await _methodChannel.invokeMethod('ignore_icy');
  }

  /// Parse album covers from iTunes.
  Future<void> itunesArtworkParser(bool enable) async {
    await _methodChannel.invokeMethod('itunes_artwork_parser', enable);
  }

  /// Set custom metadata.
  Future<void> setCustomMetadata(List<String> metadata) async {
    await _methodChannel.invokeMethod('metadata', metadata);
  }

  /// Returns the album cover if it has already been downloaded.
  Future<Image?> getArtworkImage() async {
    final byteData = await _metadataArtworkChannel.send(ByteData(0));
    Image? image;
    if (byteData != null) image = Image.memory(byteData.buffer.asUint8List(), key: UniqueKey(), fit: BoxFit.cover);
    return image;
  }

  /// Get the playback state stream.
  Stream<bool> get stateStream {
    _stateStream ??= _stateEvents.receiveBroadcastStream().map<bool>((value) => value);
    return _stateStream!;
  }

  /// Get the metadata stream.
  Stream<List<String>> get metadataStream {
    _metadataStream ??= _metadataEvents.receiveBroadcastStream().map((metadata) {
      return metadata.map<String>((value) => value as String).toList();
    });
    return _metadataStream!;
  }
}
