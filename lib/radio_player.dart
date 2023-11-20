/*
 *  radio_player.dart
 *
 *  Created by Ilia Chirkunov <xc@yar.net> on 28.12.2020.
 */

import 'dart:async';
import 'package:flutter/services.dart';

class RadioPlayer {
  static const _methodChannel = MethodChannel('radio_player');
  static const _metadataEvents = EventChannel('radio_player/metadataEvents');
  static const _stateEvents = EventChannel('radio_player/stateEvents');

  Stream<bool>? _stateStream;
  Stream<List<String>>? _metadataStream;

  /// Set new streaming URL.
  Future<void> setChannel({required String title, required String url, required String imageUrl}) async {
    await Future.delayed(Duration(milliseconds: 500));
    await _methodChannel.invokeMethod('set', [url, title, imageUrl]);

    // if (imagePath != null) setDefaultArtwork(imagePath);
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

  /// Returns true if player is playing sound otherwise false.
  Future<bool> isPlaying() async {
    final result = await _methodChannel.invokeMethod('isPlaying');
    return result as bool;
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
