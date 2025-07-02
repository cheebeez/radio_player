/*
 * CustomRenderersFactory.kt
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

package com.cheebeez.radio_player

import android.content.Context
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.audio.AudioSink
import androidx.media3.exoplayer.audio.DefaultAudioSink

/// A custom renderer factory that injects the FFT audio processor.
class CustomRenderersFactory(
    context: Context,
    private val fftAudioProcessor: FftAudioProcessor
) : DefaultRenderersFactory(context) {

    /// This method is called by ExoPlayer when building the player.
    override fun buildAudioSink(
        context: Context,
        enableFloatOutput: Boolean,
        enableAudioTrackPlaybackParams: Boolean
    ): AudioSink? {
        val audioProcessors = arrayOf<AudioProcessor>(fftAudioProcessor)

        return DefaultAudioSink.Builder(context)
            .setAudioProcessors(audioProcessors)
            .setEnableFloatOutput(enableFloatOutput)
            .setEnableAudioTrackPlaybackParams(enableAudioTrackPlaybackParams)
            .build()
    }
}