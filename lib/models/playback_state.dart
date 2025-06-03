/*
 * playback_state.dart
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

/// Represents the playback state of the radio player.
enum PlaybackState {
  /// The player is actively playing audio.
  playing,

  /// The player is paused.
  paused,

  /// The player is buffering data.
  buffering,

  /// The player is in an unknown state or an error state.
  unknown;

  static PlaybackState fromString(String? nativeState) {
    switch (nativeState?.toLowerCase()) {
      case 'playing':
        return PlaybackState.playing;
      case 'paused':
        return PlaybackState.paused;
      case 'buffering':
        return PlaybackState.buffering;
      default:
        return PlaybackState.unknown;
    }
  }

  bool get isPlaying => this == PlaybackState.playing;
  bool get isPaused => this == PlaybackState.paused;
  bool get isBuffering => this == PlaybackState.buffering;
  bool get isUnknown => this == PlaybackState.unknown;
}
