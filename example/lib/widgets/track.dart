/*
 * track.dart
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import 'package:flutter/material.dart';

class Track extends StatelessWidget {
  const Track({super.key, this.artist, this.title});

  final String? artist;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title ?? 'Metadata',
          softWrap: false,
          overflow: TextOverflow.fade,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        Text(
          artist ?? '',
          softWrap: false,
          overflow: TextOverflow.fade,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
