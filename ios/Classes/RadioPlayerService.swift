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

    weak var playbackStateDelegate: RadioPlayerPlaybackStateDelegate?
    weak var metadataDelegate: RadioPlayerMetadataDelegate?

    var parseStreamMetadata: Bool = true
    var lookupOnlineArtwork: Bool = false

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

        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.nextTrackCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            print("iOS: Next Track Command Tapped")
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            print("iOS: Previous Track Command Tapped")
            return .success
        }

        // Sets up observers for system notifications like audio interruptions.
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, 
                object: AVAudioSession.sharedInstance())
    }

    deinit {
        player.removeObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus))
        NotificationCenter.default.removeObserver(self)
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    /// Sets the media item for playback.
    func setStation(title: String, url: String, imageData: Data?, parseStreamMetadata: Bool, lookupOnlineArtwork: Bool) {
        streamTitle = title
        streamUrl = url
        defaultArtwork = imageData != nil ? UIImage(data: imageData!) : nil

        // Update properties based on new parameters.
        self.parseStreamMetadata = parseStreamMetadata
        self.lookupOnlineArtwork = lookupOnlineArtwork

        // Update Now Playing Info with station title initially.
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: streamTitle,
        ]
        if let art = defaultArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: art.size, requestHandler: { _ in art })
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        // Create and set the new player item.
        let playerItem = AVPlayerItem(url: URL(string: streamUrl)!)
        player.replaceCurrentItem(with: playerItem)

        // Set metadata handler.
        let metaOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metaOutput.setDelegate(self, queue: DispatchQueue.main)
        playerItem.add(metaOutput)
    }

    /// Updates the player's metadata with new track information.
    func setMetadata(artist: String?, songTitle: String?, artworkUrl: String?) {
        let currentArtist = artist.nilIfEmpty()
        let currentSongTitle = songTitle.nilIfEmpty()
        var currentArtworkUrl = artworkUrl.nilIfEmpty()

        // Check if metadata has actually changed.
        let newMetadataHash = (currentArtist ?? "_nil_") + (currentSongTitle ?? "_nil_")
        if newMetadataHash == metadataHash { return }
        metadataHash = newMetadataHash

        Task {
            // Parse artwork url from iTunes.
            if (lookupOnlineArtwork && currentArtworkUrl == nil) {
                currentArtworkUrl = await ArtworkUtils.parseArtworkFromItunes(
                        artist: currentArtist ?? "", track: currentSongTitle ?? "")
            }

            // Download artwork.
            var loadedArtwork = await ArtworkUtils.downloadImage(from: currentArtworkUrl)
            loadedArtwork = loadedArtwork ?? defaultArtwork

            // Update the now playing info.
            var nowPlayingInfo: [String: Any] = [
                MPMediaItemPropertyArtist: currentArtist,
                MPMediaItemPropertyTitle: currentSongTitle
            ]

            if let image = loadedArtwork {
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }

            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

            // Send metadata to client.
            metadataDelegate?.radioPlayerDidUpdateMetadata(
                artist: currentArtist,
                title: currentSongTitle,
                artworkUrl: currentArtworkUrl,
                artworkData: loadedArtwork?.jpegData(compressionQuality: 0.8)
            )
        }
    }

    /// Starts or resumes playback.
    func play() {
         // If the player item is nil or has failed, try to set it up again.
        if player.currentItem == nil || player.currentItem?.isPlaybackBufferEmpty == true || player.currentItem?.status == .failed {
            setStation(
                title: streamTitle, 
                url: streamUrl, 
                imageData: defaultArtwork?.jpegData(compressionQuality: 1.0), 
                parseStreamMetadata: parseStreamMetadata, 
                lookupOnlineArtwork: lookupOnlineArtwork
            )
        }

        player.play()
    }

    /// Pauses playback.
    func pause() {
        player.pause()
    }

    /// Stops playback, removes notification, and fully resets player state for the next station.
    func reset() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        streamTitle = nil
        streamUrl = nil
        defaultArtwork = nil
        metadataHash = nil
    }

    /// Updates the visibility of the next and previous track remote command buttons.
    public func setNavigationControls(showNext: Bool, showPrevious: Bool) {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.nextTrackCommand.isEnabled = showNext
        commandCenter.previousTrackCommand.isEnabled = showPrevious

        if let currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
             MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
        }
    }

    /// Observes changes in player properties, like playback state.
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == #keyPath(AVPlayer.timeControlStatus), let newStatusNumber = change?[.newKey] as? NSNumber else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }

        let newStatus = AVPlayer.TimeControlStatus(rawValue: newStatusNumber.intValue)
        var playbackState: String

        if let status = newStatus {
            switch status {
                case .playing:
                    playbackState = "playing"
                case .waitingToPlayAtSpecifiedRate:
                    playbackState = "buffering"
                case .paused:
                    playbackState = "paused"
                @unknown default:
                    playbackState = "unknown"
            }
        } else {
            playbackState = "unknown" 
        }

        playbackStateDelegate?.radioPlayerDidChangePlaybackState(playbackState: playbackState)
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
        if !parseStreamMetadata { return }

        guard let firstGroup = groups.first, !firstGroup.items.isEmpty else { return }
        let metaItems = firstGroup.items

        guard var streamTitle: String = metaItems.first?.stringValue?.nilIfEmpty() else { return }

        var artist: String? = nil
        var songTitle: String? = nil
        var artworkUrlFromIcy: String? = nil

        if metaItems.count > 1 {
            artworkUrlFromIcy = metaItems[1].stringValue?.nilIfEmpty()
        }

        // Check if songTitle is in "Artist - Title" format
        let parts = streamTitle.components(separatedBy: " - ")
        if parts.count == 2 {
            artist = parts[0].nilIfEmpty()
            songTitle = parts[1].nilIfEmpty()
        } else {
            songTitle = streamTitle.nilIfEmpty()
        }

        // Update metadata
        setMetadata(artist: artist, songTitle: songTitle, artworkUrl: artworkUrlFromIcy)
    }
}
