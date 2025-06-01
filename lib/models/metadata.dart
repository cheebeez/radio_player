/*
 * metadata.dart
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import 'dart:typed_data';

/// Represents the metadata for a radio stream.
class Metadata {
  final String? artist;
  final String? title;
  final String? artworkUrl;
  final Uint8List? artworkData;

  Metadata({
    required this.artist,
    required this.title,
    this.artworkUrl,
    this.artworkData,
  });

  factory Metadata.fromMap(Map<dynamic, dynamic> map) {
    return Metadata(
      artist: map['artist'] as String?,
      title: map['title'] as String?,
      artworkUrl: map['artworkUrl'] as String?,
      artworkData: map['artworkData'] as Uint8List?,
    );
  }
}
