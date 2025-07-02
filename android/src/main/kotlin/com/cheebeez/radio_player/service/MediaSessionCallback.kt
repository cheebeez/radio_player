/*
 * MediaSessionCallback.kt
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */
 
package com.cheebeez.radio_player

import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSession.ConnectionResult
import android.util.Log
import androidx.media3.common.MediaMetadata
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.Futures
import androidx.media3.session.SessionResult
import androidx.media3.session.SessionCommand
import android.os.Bundle

/// Manages MediaSession interactions, connections, and custom command handling.
class MediaSessionCallback(private val radioPlayerService: RadioPlayerService) : MediaSession.Callback {

    /// Called when a MediaController requests to connect to this MediaSession.
    override fun onConnect(
        session: MediaSession,
        controller: MediaSession.ControllerInfo
    ): MediaSession.ConnectionResult {

        // Allow connections from our app or the system media notification controller.
        if (session.isMediaNotificationController(controller) || controller.packageName == radioPlayerService.packageName) {
            // Define the custom session commands supported by this media session.
            val customCommands = mutableListOf<SessionCommand>()
            customCommands.add(SessionCommand(RadioPlayerService.CUSTOM_COMMAND_SET_STATION, Bundle.EMPTY))
            customCommands.add(SessionCommand(RadioPlayerService.CUSTOM_COMMAND_SET_CUSTOM_METADATA, Bundle.EMPTY))
            customCommands.add(SessionCommand(RadioPlayerService.CUSTOM_COMMAND_RESET, Bundle.EMPTY))
            customCommands.add(SessionCommand(RadioPlayerService.CUSTOM_COMMAND_SET_NAVIGATION_CONTROLS, Bundle.EMPTY))
            customCommands.add(SessionCommand(RadioPlayerService.CUSTOM_COMMAND_SET_VISUALIZER_ENABLED, Bundle.EMPTY))

            // Build the full set of available session commands (default + custom).
            val availableSessionCommandsBuilder = ConnectionResult.DEFAULT_SESSION_COMMANDS.buildUpon()
            customCommands.forEach { availableSessionCommandsBuilder.add(it) }

            // Get the player commands supported by the session's underlying player.
            val availablePlayerCommands = Player.Commands.Builder()
                .addAll(session.player.availableCommands)
                .add(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM)
                .add(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
                .remove(Player.COMMAND_SEEK_TO_NEXT)
                .remove(Player.COMMAND_SEEK_TO_PREVIOUS)

            // Accept the connection, providing the supported session and player commands.
            return MediaSession.ConnectionResult.AcceptedResultBuilder(session)
                .setAvailableSessionCommands(availableSessionCommandsBuilder.build())
                .setAvailablePlayerCommands(availablePlayerCommands.build())
                .build()
        } 

        // For other controllers, use default connection behavior (usually rejection).
        return super.onConnect(session, controller)
    }

    /// Called when a MediaController sends a custom command to this MediaSession.
    override fun onCustomCommand(
        session: MediaSession,
        controller: MediaSession.ControllerInfo,
        customCommand: SessionCommand,
        args: Bundle
    ): ListenableFuture<SessionResult> {
       when (customCommand.customAction) {
            RadioPlayerService.CUSTOM_COMMAND_SET_STATION -> {
                val title = args.getString("title")!!
                val url = args.getString("url")!!
                val imageData = args.getByteArray("image_data")
                val parseStreamMetadata = args.getBoolean("parseStreamMetadata")!!
                val lookupOnlineArtwork = args.getBoolean("lookupOnlineArtwork")!!

                radioPlayerService.setStation(title, url, imageData, parseStreamMetadata, lookupOnlineArtwork)
                return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
            }

            RadioPlayerService.CUSTOM_COMMAND_SET_CUSTOM_METADATA -> {
                val artist = args.getString("artist")
                val title = args.getString("title")
                val artworkUrl = args.getString("artworkUrl")

                radioPlayerService.setMetadata(artist, title, artworkUrl)
                return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
            }

            RadioPlayerService.CUSTOM_COMMAND_SET_NAVIGATION_CONTROLS -> {
                val showNext = args.getBoolean("showNext")
                val showPrevious = args.getBoolean("showPrevious")
                radioPlayerService.setNavigationControls(showNext, showPrevious)
                return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
            }

            RadioPlayerService.CUSTOM_COMMAND_SET_VISUALIZER_ENABLED -> {
                val enabled = args.getBoolean("enabled")
                radioPlayerService.setVisualizerEnabled(enabled)
                return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
            }

             RadioPlayerService.CUSTOM_COMMAND_RESET -> { 
                radioPlayerService.reset()
                return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
            }
        }

        return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
    }
}