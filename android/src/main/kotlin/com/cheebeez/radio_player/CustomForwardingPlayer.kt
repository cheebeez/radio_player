/*
 *  CustomForwardingPlayer.kt
 *
 *  Created by Ilia Chirkunov <contact@cheebeez.com> on 21.05.2025.
 */

package com.cheebeez.radio_player

import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer

import android.util.Log
import androidx.media3.common.MediaMetadata
import androidx.media3.common.MediaItem

///
class CustomForwardingPlayer(player: ExoPlayer) : ForwardingPlayer(player) {

    ///
    override fun getAvailableCommands(): Player.Commands {
        return super.getAvailableCommands().buildUpon()
            .add(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM)
            .add(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
            .build()
    }

    ///
    override fun isCommandAvailable(command: @Player.Command Int): Boolean {
        if (command == Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM ||
            command == Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM) {
            return true
        }

        return super.isCommandAvailable(command)
    }

    ///
    override fun seekToNextMediaItem() {
    }

    ///
    override fun seekToPreviousMediaItem() {
    }

}
