/*
 *  RadioPlayer.swift
 *
 *  Created by Ilia Chirkunov <xc@yar.net> on 10.01.2021.
 */

import MediaPlayer
import AVKit

class RadioPlayer: NSObject, AVPlayerItemMetadataOutputPushDelegate {
    private var player: AVPlayer!
    private var playerItem: AVPlayerItem!
    var defaultArtwork: UIImage?
    var metadataArtwork: UIImage?
    var streamTitle: String!
    var streamUrl: String!
    var ignoreIcy: Bool = false
    var itunesArtworkParser: Bool = false
    var interruptionObserverAdded: Bool = false
  
    private(set) var isAvailableInControlCenter = false
    private(set) var metadataArtist: String?
    private(set) var metadataTrack: String?
    
    private var playerStopDate: Date?
    private var timer: Timer?
  
    deinit {
        removeTimeObserver()
    }
  
    func setMediaItem() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: streamTitle, ]
        defaultArtwork = nil
        metadataArtwork = nil
        playerItem = AVPlayerItem(url: URL(string: streamUrl)!)

        if (player == nil) {
            // Create an AVPlayer.
            player = AVPlayer(playerItem: playerItem)
            player.automaticallyWaitsToMinimizeStalling = true
            player.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), options: [.new], context: nil)
            runInBackground()
        } else {
            player.replaceCurrentItem(with: playerItem)
        }

        // Set interruption handler.
        if (!interruptionObserverAdded) {
            NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlay), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
            interruptionObserverAdded = true
        }

        // Set metadata handler.
        let metaOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metaOutput.setDelegate(self, queue: DispatchQueue.main)
        playerItem.add(metaOutput)
    }

    func setMetadata(_ rawMetadata: Array<String>) {
        var metadata: Array<String> = rawMetadata.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        // Parse artwork from iTunes.
        if (itunesArtworkParser && metadata[2].isEmpty) {
            metadata[2] = parseArtworkFromItunes(metadata[0], metadata[1])
        }

        metadataArtist = metadata[0]
        metadataTrack = metadata[1]
        // Download album cover
        metadataArtwork = downloadImage(metadata[2])
      
        if isAvailableInControlCenter {
            // Update the now playing info
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [
              MPMediaItemPropertyArtist: metadataArtist, MPMediaItemPropertyTitle: metadataTrack, ]
            
            // Download and set album cover
            setArtwork(metadataArtwork ?? defaultArtwork)
        }

        // Send metadata to client
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "metadata"), object: nil, userInfo: ["metadata": metadata])
    }

    /// Resume playback after phone call.
    @objc func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
        }
        if type == .began {

        } else if type == .ended {
            guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
                    return
            }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                play()
            }
        }
    }

    /// TODO: Attempt to reconnect when disconnecting.
    @objc func playerItemFailedToPlay(_ notification: Notification) {

    }

    func setArtwork(_ image: UIImage?) {
        guard let image = image else { return }

        let artwork = MPMediaItemArtwork(boundsSize: image.size) { (size) -> UIImage in image }
        MPNowPlayingInfoCenter.default().nowPlayingInfo?.updateValue(artwork, forKey: MPMediaItemPropertyArtwork)
    }

    func play() {
        setMediaItem()
        player.play()
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
    }

    func pause() {
        player.pause()
    }
    
    func removeFromBackground() {
        UIApplication.shared.endReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(self)
        commandCenter.pauseCommand.removeTarget(self)
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
      
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    func runInBackground() {
        isAvailableInControlCenter = true
        try? AVAudioSession.sharedInstance().setActive(true)
        try? AVAudioSession.sharedInstance().setCategory(.playback)

        // Control buttons on the lock screen.
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()

        // Play button.
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            self?.play()
            return .success
        }

        // Pause button.
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] (event) -> MPRemoteCommandHandlerStatus in
            self?.stop()
            return .success
        }
    }
  
    func addToControlCenter() {
        isAvailableInControlCenter = true
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [ MPMediaItemPropertyTitle: metadataTrack ?? streamTitle ]
        if let metadataArtist = metadataArtist {
          MPNowPlayingInfoCenter.default().nowPlayingInfo?.updateValue(metadataArtist, forKey: MPMediaItemPropertyArtist)
        }
        setArtwork(metadataArtwork ?? defaultArtwork)
    }
    
    func removeFromControlCenter() {
        isAvailableInControlCenter = false
        UIApplication.shared.endReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
      
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
  
    func stopPlayer(after seconds: TimeInterval) {
        let seconds = max(1.0, seconds)
        playerStopDate = Date(timeIntervalSinceNow: seconds)
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
              guard let self = self,
                    let playerStopDate = self.playerStopDate,
                    Date() >= playerStopDate else { return }
              self.removeTimeObserver()
              self.stop()
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        self.timer = timer
    }
  
    func cancelTimer() {
        removeTimeObserver()
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let observedKeyPath = keyPath, object is AVPlayer, observedKeyPath == #keyPath(AVPlayer.timeControlStatus) else {
            return
        }

        if let statusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
            let status = AVPlayer.TimeControlStatus(rawValue: statusAsNumber.intValue)

            if status == .paused {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "state"), object: nil, userInfo: ["state": false])
            } else if status == .waitingToPlayAtSpecifiedRate {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "state"), object: nil, userInfo: ["state": true])
            }
        }
    }

    func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
                from track: AVPlayerItemTrack?) {
        if (ignoreIcy) { return }

        var metadata: Array<String>!
        let metaDataItems = groups.first.map({ $0.items })

        // Parse title
        guard let title = metaDataItems?.first?.stringValue else { return }
        metadata = title.components(separatedBy: " - ")
        if (metadata.count == 1) { metadata.append("") }

        // Parse artwork
        metaDataItems!.count > 1 ? metadata.append(metaDataItems![1].stringValue!) : metadata.append("")

        // Update metadata
        setMetadata(metadata)
    }

    func downloadImage(_ value: String) -> UIImage? {
        guard let url = URL(string: value) else { return nil }

        var result: UIImage?
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let data = data, error == nil {
                result = UIImage(data: data)
            }
            semaphore.signal()
        }
        task.resume()

        let _ = semaphore.wait(timeout: .distantFuture)
        return result
    }

    func parseArtworkFromItunes(_ artist: String, _ track: String) -> String {
        var artwork: String = ""

        // Generate a request.
        guard let term = (artist + " - " + track).addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        else { return artwork }

        guard let url = URL(string: "https://itunes.apple.com/search?term=" + term + "&limit=1")
        else { return artwork }

        // Download content.
        var jsonData: Data?
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let data = data, error == nil {
                jsonData = data
            }
            semaphore.signal()
        }

        task.resume()
        let _ = semaphore.wait(timeout: .distantFuture)

        // Convert content to Dictonary.
        guard let jsonData = jsonData else { return artwork }
        guard let dict = try? JSONSerialization.jsonObject(with: jsonData, options: .allowFragments) as? [String:Any]
        else { return artwork }

        // Make sure the result is found.
        guard let _ = dict["resultCount"], dict["resultCount"] as! Int > 0 else { return artwork }

        // Get artwork
        guard let results = dict["results"] as? Array<[String:Any]> else { return artwork }
        guard let artworkUrl30 = results[0]["artworkUrl30"] as? String else { return artwork }
        artwork = artworkUrl30.replacingOccurrences(of: "30x30bb", with: "500x500bb")

        return artwork
    }
  
  private func removeTimeObserver() {
    playerStopDate = nil
    timer?.invalidate()
    timer = nil
  }
}
