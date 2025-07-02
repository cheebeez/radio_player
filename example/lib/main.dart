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
import 'package:radio_player/radio_player.dart';
import 'package:radio_player_example/widgets/play_button.dart';
import 'package:radio_player_example/widgets/artwork.dart';
import 'package:radio_player_example/widgets/track.dart';
import 'package:radio_player_example/widgets/visualizer.dart';

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
              // Displays the artwork for the current track or a default image.
              Artwork(data: _metadata?.artworkData),
              SizedBox(height: 20),

              // Displays the artist and title of the current track.
              Track(artist: _metadata?.artist, title: _metadata?.title),
              SizedBox(height: 40),

              // Renders the audio visualizer based on the live audio stream.
              Visualizer(visualizerData: _visualizerData),
            ],
          ),
        ),

        // A FloatingActionButton that controls playback.
        floatingActionButton: PlayButton(playbackState: _playbackState),
      ),
    );
  }
}
