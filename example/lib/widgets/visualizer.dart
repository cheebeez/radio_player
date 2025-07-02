/*
 * visualizer.dart
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import 'dart:math';
import 'package:flutter/material.dart';

class Visualizer extends StatelessWidget {
  const Visualizer({super.key, required this.visualizerData});

  final List<int> visualizerData;
  final double maxHeight = 20.0;

  @override
  Widget build(BuildContext context) {
    final lowValue = visualizerData.length < 16 ? 0 : visualizerData[0];
    final midValue = visualizerData.length < 16 ? 0 : visualizerData[8];
    final highValue = visualizerData.length < 16 ? 0 : visualizerData[15];

    return SizedBox(
      height: maxHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBar((lowValue / 255.0) * maxHeight),
          const SizedBox(width: 3),
          _buildBar((midValue / 255.0) * maxHeight),
          const SizedBox(width: 3),
          _buildBar((highValue / 255.0) * maxHeight),
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
