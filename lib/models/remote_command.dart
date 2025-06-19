/*
 * remote_command.dart
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

/// Represents remote commands that can be received from the native platform.
enum RemoteCommand {
  /// Command to skip to the next track or item.
  nextTrack,

  /// Command to skip to the previous track or item.
  previousTrack,

  /// An unknown or unsupported command.
  unknown;

  static RemoteCommand fromString(String? commandString) {
    switch (commandString) {
      case 'nextTrack':
        return RemoteCommand.nextTrack;
      case 'previousTrack':
        return RemoteCommand.previousTrack;
      default:
        return RemoteCommand.unknown;
    }
  }
}
