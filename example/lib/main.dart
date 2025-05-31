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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(RadioPlayerApp());
}

class RadioPlayerApp extends StatefulWidget {
  const RadioPlayerApp({super.key});

  @override
  State<RadioPlayerApp> createState() => _RadioPlayerAppState();
}

class _RadioPlayerAppState extends State<RadioPlayerApp> {
  final _radioPlayer = RadioPlayer();
  bool _isPlaying = false;
  List<String>? _metadata;

  StreamSubscription? _stateSubscription;
  StreamSubscription? _metadataSubscription;

  @override
  void initState() {
    super.initState();

    _radioPlayer.setChannel(
      title: 'Radio Player',
      url: 'http://stream-uk1.radioparadise.com/aac-320',
      imagePath: 'assets/cover.jpg',
    );

    _stateSubscription = _radioPlayer.stateStream.listen((isPlaying) {
      setState(() => _isPlaying = isPlaying);
    });

    _metadataSubscription = _radioPlayer.metadataStream.listen((metadata) {
      setState(() => _metadata = metadata);
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _metadataSubscription?.cancel();
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
              Artwork(data: _radioPlayer.artworkData),
              SizedBox(height: 20),
              Track(artist: _metadata?[0], title: _metadata?[1]),
              SizedBox(height: 20),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _isPlaying ? _radioPlayer.pause() : _radioPlayer.play();
          },
          tooltip: 'Control button',
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
        ),
      ),
    );
  }
}

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
