/*
 * main.dart
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:radio_player/radio_player.dart';

import 'dart:math';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RadioPlayerExample());
}

class RadioPlayerExample extends StatefulWidget {
  const RadioPlayerExample({super.key});

  @override
  State<RadioPlayerExample> createState() => _RadioPlayerExampleState();
}

class _RadioPlayerExampleState extends State<RadioPlayerExample> {
  PlaybackState _playbackState = PlaybackState.paused;
  Metadata? _metadata;
  List<int> _visualizerData = const [];

  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _metadataSubscription;
  StreamSubscription? _remoteCommandSubscription;
  StreamSubscription? _visualizerSubscription;

  /// Initializes the plugin and starts listening to streams.
  @override
  void initState() {
    super.initState();

    // Set the initial radio station.
    RadioPlayer.setStation(
      title: 'Radio Player',
      url: 'http://stream-uk1.radioparadise.com/aac-320',
      logoAssetPath: 'assets/cover.jpg',
    );

    // Listen to playback state changes.
    _playbackStateSubscription = RadioPlayer.playbackStateStream.listen((
      playbackState,
    ) {
      _playbackState = playbackState;
      setState(() {});
    });

    // Listen to metadata changes.
    _metadataSubscription = RadioPlayer.metadataStream.listen((metadata) {
      _metadata = metadata;
      setState(() {});
    });

    // Enable the next and previous track buttons.
    RadioPlayer.setNavigationControls(
      showNextButton: true,
      showPreviousButton: true,
    );

    // Listen to remote control commands.
    _remoteCommandSubscription = RadioPlayer.remoteCommandStream.listen((
      command,
    ) {
      debugPrint('Remote command received: $command');
    });

    // Enable the audio visualizer.
    RadioPlayer.setVisualizerEnabled(true);

    // Listen to the visualizer data stream.
    _visualizerSubscription = RadioPlayer.visualizerStream.listen((value) {
      _visualizerData = value;
      setState(() {});
    });
  }

  /// Disposes of stream subscriptions.
  @override
  void dispose() {
    _playbackStateSubscription?.cancel();
    _metadataSubscription?.cancel();
    _remoteCommandSubscription?.cancel();
    _visualizerSubscription?.cancel();

    RadioPlayer.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(centerTitle: true, title: const Text('Radio Player')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Artwork(data: _metadata?.artworkData),
              SizedBox(height: 20),
              Track(artist: _metadata?.artist, title: _metadata?.title),
              SizedBox(height: 20),
              AudioVisualizer(visualizerData: _visualizerData),
            ],
          ),
        ),
        floatingActionButton: PlayButton(playbackState: _playbackState),
      ),
    );
  }
}

/// A FloatingActionButton that controls playback.
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

/// Displays the artwork for the current track or a default image.
class Artwork extends StatelessWidget {
  const Artwork({super.key, required this.data});

  final Uint8List? data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      width: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child:
            data == null
                ? Image.asset('assets/cover.jpg', fit: BoxFit.cover)
                : Image.memory(data!, key: UniqueKey(), fit: BoxFit.cover),
      ),
    );
  }
}

/// Displays the artist and title of the current track.
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

class AudioVisualizer extends StatelessWidget {
  const AudioVisualizer({super.key, required this.visualizerData});

  final List<int> visualizerData;
  final double maxHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    if (visualizerData.length < 15) {
      return SizedBox(
        height: maxHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(0),
            const SizedBox(width: 5),
            _buildBar(0),
            const SizedBox(width: 5),
            _buildBar(0),
          ],
        ),
      );
    }

    final lowValue = visualizerData[4];
    final midValue = visualizerData[8];
    final highValue = visualizerData[12];

    final lowHeight = (lowValue / 255.0) * maxHeight;
    final midHeight = (midValue / 255.0) * maxHeight;
    final highHeight = (highValue / 255.0) * maxHeight;

    return SizedBox(
      height: maxHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBar(lowHeight),
          const SizedBox(width: 5),
          _buildBar(midHeight),
          const SizedBox(width: 5),
          _buildBar(highHeight),
        ],
      ),
    );
  }

  Widget _buildBar(double height) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      height: max(5, height),
      width: 7,
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(1),
          topRight: Radius.circular(1),
        ),
      ),
    );
  }
}
