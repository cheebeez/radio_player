/*
 * artwork.dart
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

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
