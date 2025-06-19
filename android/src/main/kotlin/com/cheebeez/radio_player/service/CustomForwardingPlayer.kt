/*
 * CustomForwardingPlayer.kt
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

package com.cheebeez.radio_player

import android.util.Log
import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.common.MediaItem

/// A custom ForwardingPlayer that wraps an ExoPlayer instance.
class CustomForwardingPlayer(player: ExoPlayer) : ForwardingPlayer(player) {

var seekToNext: Boolean = false
var seekToPrevious: Boolean = false

    /// Overrides available commands.
    override fun getAvailableCommands(): Player.Commands {
        val builder = super.getAvailableCommands().buildUpon()

        if (seekToNext) {
            builder.add(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM)
        } else {
            builder.remove(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM)
        }

        if (seekToPrevious) {
            builder.add(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
        } else {
            builder.remove(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
        }

        return builder.build()
    }

    /// Checks if a specific command is available.
    override fun isCommandAvailable(command: @Player.Command Int): Boolean {
        return when (command) {
            Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM  -> seekToNext
            Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM -> seekToPrevious
            else -> super.isCommandAvailable(command)
        }
    }

    /// Overrides seeking to the next media item.
    override fun seekToNextMediaItem() {
        Log.d("CustomForwardingPlayer","seekToNextMediaItem")
    }

    /// Overrides seeking to the previous media item.
    override fun seekToPreviousMediaItem() {
        Log.d("CustomForwardingPlayer","seekToPreviousMediaItem")
    }
}
