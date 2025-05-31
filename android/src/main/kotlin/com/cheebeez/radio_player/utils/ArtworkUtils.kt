/*
 * ArtworkUtils.kt
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

package com.cheebeez.radio_player

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.URL
import java.net.URLEncoder

/// Downloads an image from a URL.
suspend fun downloadImage(value: String?): ByteArray? {
    if (value == null) return null

    return try {
        withContext(Dispatchers.IO) {
            val url = URL(value)
            url.openStream().use { inputStream ->
                inputStream.readBytes()
            }
        }
    } catch (e: Throwable) {
        Log.e("ArtworkUtils", "Error downloading image: ${e.message}") 
        null
    }
}

/// Fetches an artwork URL from iTunes API for the given artist and track.
suspend fun parseArtworkFromItunes(artist: String, track: String): String {
    if (artist.isBlank() && track.isBlank()) return ""

    return try {
        val term = URLEncoder.encode("$artist - $track".trim(), "utf-8")

        val response = withContext(Dispatchers.IO) {
            URL("https://itunes.apple.com/search?term=$term&media=music&entity=song&limit=1").readText()
        }

        val jsonObject = JSONObject(response)
        var artwork = ""

        if (jsonObject.getInt("resultCount") > 0) {
            val artworkUrl30: String = jsonObject.getJSONArray("results").getJSONObject(0).getString("artworkUrl30")
            artwork = artworkUrl30.replace("30x30bb","500x500bb")
        }

        artwork
    } catch (e: Throwable) {
        Log.e("ArtworkUtils", "Error parsing artwork from iTunes: ${e.message}")
        ""
    }
}
