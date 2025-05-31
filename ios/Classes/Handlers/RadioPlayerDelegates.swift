/*
 * RadioPlayerDelegates.swift
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import Foundation

/// Delegate protocol for radio player state changes.
protocol RadioPlayerStateDelegate: AnyObject {
    func radioPlayerDidChangeState(isPlaying: Bool)
}

/// Delegate protocol for radio player metadata updates.
protocol RadioPlayerMetadataDelegate: AnyObject {
    func radioPlayerDidUpdateMetadata(artist: String, title: String, artworkUrl: String?, artworkData: Data?)
}
