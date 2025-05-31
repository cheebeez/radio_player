/*
 * RadioPlayerService.swift
 *
 * Copyright (c) 2020-2025 Ilia Chirkunov <contact@cheebeez.com>
 *
 * This source code is licensed under the CC BY-NC-SA 4.0.
 * See https://creativecommons.org/licenses/by-nc-sa/4.0/
 */

import MediaPlayer
import AVKit

/// Manages the AVPlayer instance for streaming radio playback and handles audio session configuration.
class RadioPlayerService: NSObject {
    private var player: AVPlayer!
    var streamTitle: String!
    var streamUrl: String!
    var defaultArtwork: UIImage?
    private var metadataHash: String? = nil

    weak var stateDelegate: RadioPlayerStateDelegate?
    weak var metadataDelegate: RadioPlayerMetadataDelegate?

    var ignoreIcy: Bool = false
    var itunesArtworkParser: Bool = false

    /// Initialization
    override init() {
        super.init()

        player = AVPlayer()
        player.automaticallyWaitsToMinimizeStalling = true

        // Adds observers for player properties.
        player.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), options: [.old, .new], context: nil)

        // Configures the audio session for playback.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("RadioPlayerSevice: Failed to set up audio session: \(error)")
        }

        // Configures remote command center controls (e.g., lock screen controls).
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            self?.pause()
            return .success
        }

        // Sets up observers for system notifications like audio interruptions.
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
    }

    deinit {
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus))
        NotificationCenter.default.removeObserver(self)
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

     /// Sets the media item for playback.
    func setMediaItem(title: String, url: String, imageData: Data?) {
        streamTitle = title
        streamUrl = url
        defaultArtwork = imageData != nil ? UIImage(data: imageData!) : nil

        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: streamTitle, ]

        let playerItem = AVPlayerItem(url: URL(string: streamUrl)!)
        player.replaceCurrentItem(with: playerItem)

        // Set metadata handler.
        let metaOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metaOutput.setDelegate(self, queue: DispatchQueue.main)
        playerItem.add(metaOutput)
    }

    /// Updates the player's metadata with new track information.
    func setMetadata(artist: String, songTitle: String, artworkUrl: String?) {
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSongTitle = songTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var trimmedArtworkUrl = artworkUrl?.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if metadata has actually changed.
        let currentMetadataHash = trimmedArtist + trimmedSongTitle
        if currentMetadataHash == metadataHash { return }
        metadataHash = currentMetadataHash

        Task {
            // Parse artwork url from iTunes.
            if (itunesArtworkParser && (artworkUrl ?? "").isEmpty) {
                trimmedArtworkUrl = await ArtworkUtils.parseArtworkFromItunes(artist: trimmedArtist, track: trimmedSongTitle)
            }

            // Download artwork.
            var loadedArtwork = await ArtworkUtils.downloadImage(from: trimmedArtworkUrl)
            loadedArtwork = loadedArtwork ?? defaultArtwork

            // Update the now playing info.
            var nowPlayingInfo: [String: Any] = [
                MPMediaItemPropertyArtist: trimmedArtist,
                MPMediaItemPropertyTitle: trimmedSongTitle
            ]

            if let image = loadedArtwork {
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }

            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

            // Send metadata to client.
            metadataDelegate?.radioPlayerDidUpdateMetadata(
                artist: trimmedArtist ?? "",
                title: trimmedSongTitle ?? "",
                artworkUrl: trimmedArtworkUrl ?? "",
                artworkData: loadedArtwork?.jpegData(compressionQuality: 0.8)
            )
        }
    }

    /// Starts or resumes playback.
    func play() {
         // If the player item is nil or has failed, try to set it up again.
        if player.currentItem == nil || player.currentItem?.isPlaybackBufferEmpty == true || player.currentItem?.status == .failed {
             setMediaItem(title: streamTitle, url: streamUrl, imageData: defaultArtwork?.jpegData(compressionQuality: 1.0))
        }

        player.play()
    }

    /// Pauses playback.
    func pause() {
        player.pause()
    }

    /// Stops playback.
    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    /// Observes changes in player properties, like playback state.
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == #keyPath(AVPlayer.timeControlStatus), let newStatusNumber = change?[.newKey] as? NSNumber else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }

        let newStatus = AVPlayer.TimeControlStatus(rawValue: newStatusNumber.intValue)
        var isPlaying = false
        switch newStatus {
            case .playing:
                isPlaying = true
            case .waitingToPlayAtSpecifiedRate:
                isPlaying = true
            case .paused:
                isPlaying = false
            case .none:
                isPlaying = false
            @unknown default:
                isPlaying = false
        }
        stateDelegate?.radioPlayerDidChangeState(isPlaying: isPlaying)
    }

    /// Handles audio session interruptions (e.g., phone calls).
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
            case .began:
                // Interruption began, playback is paused by the system.
                break
            case .ended:
                // Interruption ended.
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        play()
                    }
                }
        }
    }

}

/// This extension handles timed metadata received from the audio stream.
extension RadioPlayerService: AVPlayerItemMetadataOutputPushDelegate {

    /// Processes incoming ICY (stream) metadata.
    func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup], from track: AVPlayerItemTrack?) {
        if ignoreIcy { return }

        let rawMetadata = groups.first.map({ $0.items })

        var artist = ""
        guard var songTitle = rawMetadata?.first?.stringValue else { return }
        let artworkUrlFromIcy = rawMetadata!.count > 1 ? rawMetadata![1].stringValue! : ""

        // Check if songTitle is in "Artist - Title" format
        let parts = songTitle.components(separatedBy: " - ")
        if parts.count == 2 {
            artist = parts[0]
            songTitle = parts[1]
        }

        // Update metadata
        setMetadata(artist: artist, songTitle: songTitle, artworkUrl: artworkUrlFromIcy)
    }
}