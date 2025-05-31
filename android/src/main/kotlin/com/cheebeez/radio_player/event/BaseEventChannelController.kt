/*
 * BaseEventChannelController.kt
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

package com.cheebeez.radio_player

import androidx.media3.session.MediaController
import io.flutter.plugin.common.BinaryMessenger

interface EventChannelController {
    fun attach(messenger: BinaryMessenger)
    fun detach()
    fun setMediaController(controller: MediaController?)
}