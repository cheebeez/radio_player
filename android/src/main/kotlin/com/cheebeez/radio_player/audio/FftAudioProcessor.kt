/*
 * FftAudioProcessor.kt
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

package com.cheebeez.radio_player

import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.C
import com.cheebeez.radio_player.VisualizerEventsController
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.jtransforms.fft.DoubleFFT_1D
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.hypot
import kotlin.math.log10

/// Processes a real-time audio stream to generate data for a visualizer.
class FftAudioProcessor(private val coroutineScope: CoroutineScope) : AudioProcessor {

    companion object {
        // The size of the FFT. Must be a power of 2.
        private const val FFT_SIZE = 1024

        // The number of frequency bands to generate for the visualizer.
        private const val BANDS_COUNT = 16

        // The minimum time in milliseconds between sending visualizer updates to Flutter.
        private const val UPDATE_INTERVAL_MS: Long = 100

        // Percentage of the lowest frequencies to cut off from the visualization.
        private const val LOW_FREQUENCY_TRIM_PERCENT = 0.2

        // Percentage of the highest frequencies to cut off from the visualization.
        private const val HIGH_FREQUENCY_TRIM_PERCENT = 0.2

        // The dynamic range in decibels used for scaling the magnitude.
        private const val DYNAMIC_RANGE_DB = 60.0
    }

    var isEnabled: Boolean = false
    private var sampleRateHz: Int = 0
    private var channelCount: Int = 0
    private var lastUpdateTime: Long = 0

    private val fft = DoubleFFT_1D(FFT_SIZE.toLong())
    private val fftInputBuffer = DoubleArray(FFT_SIZE)
    private var inputBuffer = ByteBuffer.allocate(0).order(ByteOrder.nativeOrder())
    private var outputBuffer: ByteBuffer = AudioProcessor.EMPTY_BUFFER
    private var streamEnded = false

    /// Configures the processor based on the incoming audio format.
    override fun configure(inputAudioFormat: AudioProcessor.AudioFormat): AudioProcessor.AudioFormat {
        if (inputAudioFormat.encoding != C.ENCODING_PCM_16BIT) {
            throw AudioProcessor.UnhandledAudioFormatException(inputAudioFormat)
        }
        sampleRateHz = inputAudioFormat.sampleRate
        channelCount = inputAudioFormat.channelCount
        return inputAudioFormat
    }

    /// Queues a block of audio data for processing.
    override fun queueInput(buffer: ByteBuffer) {
        if (!buffer.hasRemaining()) return

        val readOnlyBuffer = buffer.asReadOnlyBuffer()

        val remaining = readOnlyBuffer.remaining()
        if (inputBuffer.capacity() < remaining) {
            inputBuffer = ByteBuffer.allocateDirect(inputBuffer.position() + remaining).order(ByteOrder.nativeOrder())
        }
        inputBuffer.put(readOnlyBuffer)
        inputBuffer.flip()

        // Process in chunks of FFT_SIZE. Each sample is 2 bytes (16-bit).
        while (inputBuffer.remaining() >= FFT_SIZE * 2) {
            processFft()
        }

        inputBuffer.compact()
        outputBuffer = buffer
    }

    /// Extracts one block of data from the buffer, performs the FFT.
    private fun processFft() {
        for (i in 0 until FFT_SIZE) {
            if (inputBuffer.remaining() < 2) break
            fftInputBuffer[i] = (inputBuffer.getShort() / 32768.0)
        }

        coroutineScope.launch(Dispatchers.Default) {
            val fftOutput = fftInputBuffer.clone()
            fft.realForward(fftOutput)
            processAndSendData(fftOutput)
        }
    }

    /// Processes the FFT result, converting it into a set of bands for the visualizer.
    private fun processAndSendData(fftOutput: DoubleArray) {
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastUpdateTime < UPDATE_INTERVAL_MS) {
            return
        }
        lastUpdateTime = currentTime

        val magnitudes = DoubleArray(FFT_SIZE / 2)
        for (i in 0 until FFT_SIZE / 2) {
            val real = fftOutput[i * 2]
            val imag = if (i * 2 + 1 < fftOutput.size) fftOutput[i * 2 + 1] else 0.0
            magnitudes[i] = hypot(real, imag)
        }

        // Cut off the very low and high frequencies to get a cleaner visualization.
        val startIndex = (magnitudes.size * LOW_FREQUENCY_TRIM_PERCENT).toInt()
        val endIndex = (magnitudes.size * (1.0 - HIGH_FREQUENCY_TRIM_PERCENT)).toInt()

        val usableBins = endIndex - startIndex
        if (usableBins <= 0) return

        val binsPerBand = usableBins / BANDS_COUNT
        if (binsPerBand == 0) return

        val processedMagnitudes = IntArray(BANDS_COUNT)

        for (i in 0 until BANDS_COUNT) {
            var bandMagnitude = 0.0
            val startBin = startIndex + (i * binsPerBand)
            val endBin = startBin + binsPerBand

            for (j in startBin until endBin) {
                if (j < magnitudes.size) {
                    bandMagnitude += magnitudes[j]
                }
            }

            val avgMagnitude = if (binsPerBand > 0) (bandMagnitude / binsPerBand) else 0.0
            if (avgMagnitude > 0.0001) {
                val dbValue = 20 * log10(avgMagnitude)
                val scaledValue = ((dbValue + DYNAMIC_RANGE_DB) / DYNAMIC_RANGE_DB) * 255.0
                
                processedMagnitudes[i] = scaledValue.toInt().coerceIn(0, 255)
            } else {
                processedMagnitudes[i] = 0
            }
        }

        VisualizerEventsController.sendData(processedMagnitudes.toList())
    }

    /// Clears the internal buffer of any accumulated data.
    override fun flush() {
        inputBuffer = ByteBuffer.allocate(0)
        inputBuffer.flip()
        outputBuffer = AudioProcessor.EMPTY_BUFFER
        streamEnded = false
    }

    /// Resets the processor to its initial state.
    override fun reset() {
        flush()
        sampleRateHz = 0
        channelCount = 0
        isEnabled = false
    }

    /// Tells ExoPlayer whether this processor is currently active.
    override fun isActive(): Boolean = isEnabled

    /// Signals that the processor has no more output data to return.
    override fun isEnded(): Boolean {
        return streamEnded && outputBuffer === AudioProcessor.EMPTY_BUFFER
    }

    /// Returns an empty buffer because this processor only analyzes the audio stream.
    override fun getOutput(): ByteBuffer {
        val bufferToReturn = outputBuffer
        outputBuffer = AudioProcessor.EMPTY_BUFFER
        return bufferToReturn
    }

    /// Called when the audio stream ends.
    override fun queueEndOfStream() {
        streamEnded = true
    }
}