/*
 * ArtworkUtils.swift
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import UIKit 
import Foundation

struct ArtworkUtils {
    /// Downloads an image from a URL.
    static func downloadImage(from urlString: String?) async -> UIImage? {
        guard let actualUrlString = urlString,
              let url = URL(string: actualUrlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("ArtworkUtils: Failed to download image from \(actualUrlString): \(error)")
            return nil
        }
    }

    /// Fetches an artwork URL from iTunes API for the given artist and track.
    static func parseArtworkFromItunes(artist: String, track: String) async -> String {
        guard let term = (artist + " - " + track).addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let url = URL(string: "https://itunes.apple.com/search?term=\(term)&limit=1")
        else { return "" }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let dict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
                  let resultCount = dict["resultCount"] as? Int, resultCount > 0,
                  let results = dict["results"] as? [[String: Any]], !results.isEmpty,
                  let artworkUrl30 = results[0]["artworkUrl30"] as? String
            else { return "" }

            let highResArtworkUrl = artworkUrl30.replacingOccurrences(of: "30x30bb", with: "500x500bb")
            return highResArtworkUrl
        } catch {
            print("ArtworkUtils: Failed to parse iTunes artwork for \(artist) - \(track): \(error)")
            return ""
        }
    }
}