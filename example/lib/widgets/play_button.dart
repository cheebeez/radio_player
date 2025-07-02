/*
 * play_button.dart
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import 'package:flutter/material.dart';
import 'package:radio_player/radio_player.dart';

class PlayButton extends StatelessWidget {
  const PlayButton({super.key, required this.playbackState});

  final PlaybackState playbackState;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget;

    if (playbackState.isBuffering) {
      iconWidget = SizedBox(
        width: 24.0,
        height: 24.0,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Colors.black45,
        ),
      );
    } else if (playbackState.isPlaying) {
      iconWidget = const Icon(Icons.pause_rounded);
    } else {
      iconWidget = const Icon(Icons.play_arrow_rounded);
    }

    return FloatingActionButton(
      onPressed: () {
        if (playbackState.isBuffering) return;
        playbackState.isPlaying ? RadioPlayer.pause() : RadioPlayer.play();
      },
      child: iconWidget,
    );
  }
}
