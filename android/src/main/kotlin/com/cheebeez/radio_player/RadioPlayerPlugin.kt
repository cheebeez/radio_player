/*
 * RadioPlayerPlugin.kt
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

package com.cheebeez.radio_player

import android.content.ComponentName
import android.content.Context
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.content.ContextCompat
import androidx.media3.session.MediaController
import androidx.media3.session.SessionCommand
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// The main plugin class for handling communication between Flutter and native Android.
class RadioPlayerPlugin: FlutterPlugin, MethodChannel.MethodCallHandler {
    private val TAG = "RadioPlayerPlugin"
    private lateinit var context: Context

    // Method Channel for Flutter to native calls.
    private lateinit var methodChannel: MethodChannel

    // Controllers for managing EventChannel communication.
    private lateinit var playbackStateEventsController: PlaybackStateEventsController
    private lateinit var metadataEventsController: MetadataEventsController

    // Coroutine scope for managing plugin-specific coroutines.
    private val pluginScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    // Media Controller for interacting with the MediaSession.
    private var mediaController: MediaController? = null
    private var controllerFuture: ListenableFuture<MediaController>? = null
    private var controllerReadyDeferred = CompletableDeferred<MediaController>()

    /// Called when the plugin is attached to the Flutter engine.
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        // Initialize Method Channel for communication from Flutter.
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "radio_player")
        methodChannel.setMethodCallHandler(this)

        // Initialize Event Channel Controllers.
        playbackStateEventsController = PlaybackStateEventsController()
        metadataEventsController = MetadataEventsController()

        // Attach Event Channel Controllers to the binary messenger.
        playbackStateEventsController.attach(flutterPluginBinding.binaryMessenger)
        metadataEventsController.attach(flutterPluginBinding.binaryMessenger)
        RemoteCommandEventsController.attach(flutterPluginBinding.binaryMessenger)
        VisualizerEventsController.attach(flutterPluginBinding.binaryMessenger)
    }

    /// Handles method calls from the Flutter side.
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        pluginScope.launch {
            val controller = ensureControllerInitialized()

            when (call.method) {
                "setStation" -> {
                    val title = call.argument<String>("title")!!
                    val url = call.argument<String>("url")!!
                    val imageData = call.argument<ByteArray?>("image_data")
                    val parseStreamMetadata = call.argument<Boolean>("parseStreamMetadata")!! 
                    val lookupOnlineArtwork = call.argument<Boolean>("lookupOnlineArtwork")!!

                    val args = Bundle().apply {
                        putString("title", title)
                        putString("url", url)
                        putByteArray("image_data", imageData)
                        putBoolean("parseStreamMetadata", parseStreamMetadata)
                        putBoolean("lookupOnlineArtwork", lookupOnlineArtwork)
                    }
                    controller.sendCustomCommand(SessionCommand(RadioPlayerService.CUSTOM_COMMAND_SET_STATION, Bundle.EMPTY), args)
                    result.success(null)
                }

                "play" -> {
                    controller.play()
                    result.success(null)
                }

                "pause" -> {
                    controller.pause()
                    result.success(null)
                }

                "stop" -> {
                    controller.stop()
                    result.success(null)
                }

                "setCustomMetadata" -> {
                    val artist = call.argument<String>("artist")
                    val title = call.argument<String>("title")
                    val artworkUrl = call.argument<String>("artworkUrl")

                    val args = Bundle().apply {
                        putString("artist", artist)
                        putString("title", title)
                        putString("artworkUrl", artworkUrl)
                    }
                    controller.sendCustomCommand(SessionCommand(RadioPlayerService.CUSTOM_COMMAND_SET_CUSTOM_METADATA, Bundle.EMPTY), args)
                    result.success(null)
                }

                 "setNavigationControls" -> {
                    val showNext = call.argument<Boolean>("showNext") ?: false
                    val showPrevious = call.argument<Boolean>("showPrevious") ?: false
                    val args = Bundle().apply {
                        putBoolean("showNext", showNext)
                        putBoolean("showPrevious", showPrevious)
                    }
                    controller.sendCustomCommand(SessionCommand(RadioPlayerService.CUSTOM_COMMAND_SET_NAVIGATION_CONTROLS, Bundle.EMPTY), args)
                    result.success(null)
                }

                "setVisualizerEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled")!!
                    val commandArgs = Bundle().apply { putBoolean("enabled", enabled) }
                    controller.sendCustomCommand(SessionCommand(RadioPlayerService.CUSTOM_COMMAND_SET_VISUALIZER_ENABLED, Bundle.EMPTY), commandArgs)
                    result.success(null)
                }

                "reset" -> {
                    controller.sendCustomCommand(SessionCommand(RadioPlayerService.CUSTOM_COMMAND_RESET, Bundle.EMPTY), Bundle.EMPTY)
                    result.success(null)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /// Called when the plugin is detached from the Flutter engine.
    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        // Clear the method call handler for the MethodChannel.
        methodChannel.setMethodCallHandler(null)
        
        // Detach Event Channel Controllers to clean up their resources.
        playbackStateEventsController.detach()
        metadataEventsController.detach()
        RemoteCommandEventsController.detach()
        VisualizerEventsController.detach()

        // Cancel all coroutines started by this plugin.
        pluginScope.cancel()

        // Release the MediaController.
        controllerFuture?.let { MediaController.releaseFuture(it) }
        mediaController = null
        controllerFuture = null

        // Cancel the deferred if it's still active.
        if (controllerReadyDeferred.isActive) {
            controllerReadyDeferred.cancel()
        }
    }

    /// Ensures the MediaController is initialized and returns it.
    private suspend fun ensureControllerInitialized(): MediaController {
        // Return immediately if MediaController is already initialized.
        if (mediaController != null) {
            return mediaController!!
        }

        // If initialization is already in progress, await its completion.
        if (controllerFuture != null && !controllerReadyDeferred.isCompleted) {
            return controllerReadyDeferred.await()
        }

        // If not initialized and no future exists, create the MediaController.
        controllerReadyDeferred = CompletableDeferred()
        val sessionToken = SessionToken(context, ComponentName(context, RadioPlayerService::class.java))
        val future = MediaController.Builder(context, sessionToken).buildAsync()
        controllerFuture = future

        // Add a listener to handle the result of the asynchronous build.
        future.addListener(
            {
                try {
                    // Successfully connected to the MediaController.
                    val controller = future.get()
                    mediaController = controller

                    // Pass the new controller to EventChannelControllers.
                    playbackStateEventsController.setMediaController(controller)
                    metadataEventsController.setMediaController(controller)

                    // Complete the deferred with the new controller.
                    if (!controllerReadyDeferred.isCompleted) {
                        controllerReadyDeferred.complete(controller)
                    }
                } catch (e: Exception) {
                    // Handle errors during MediaController connection.
                    if (!controllerReadyDeferred.isCompleted) {
                        controllerReadyDeferred.completeExceptionally(e)
                    }
                    // Reset future so a new attempt can be made.
                    controllerFuture = null 
                }
            },
            // Run listener on the main thread.
            ContextCompat.getMainExecutor(context) 
        )

        // Await completion (success or error).
        return controllerReadyDeferred.await() 
    }
}
