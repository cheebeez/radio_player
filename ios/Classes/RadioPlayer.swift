/*
 *  RadioPlayer.swift
 *
 *  Created by Ilia Chirkunov <xc@yar.net> on 10.01.2021.
 */

import MediaPlayer
import AVKit

class RadioPlayer: NSObject , AVPlayerItemMetadataOutputPushDelegate {
    private var player: AVPlayer!
    private var playerItem: AVPlayerItem!
    
    private var interruptionObserverAdded: Bool = false
    
    var isPlaying: Bool {
        guard let player = player else {
            return false
        }
        return player.rate != 0 && player.error == nil
    }
  
    private(set) var isAvailableInControlCenter = false
    private(set) var metadataArtist: String?
    private(set) var metadataTrack: String?
    
    // Stream data
    private var streamUrl = ""
    private var streamTitle = ""
    private var streamImage: UIImage?
    
    // Track data
    private var trackTitle = ""
    private var trackImage: UIImage?

    private var currentPlayerImage: UIImage?
    
    private var playerStopDate: Date?
    private var timeObserver: Any?
   
    deinit {
        removeTimeObserver()
    }
    
    func setStream(streamUrl: String, title: String, streamImageUrl: String) {
        if(self.streamUrl == streamUrl) {return}
        self.streamUrl = streamUrl
        playerItem = AVPlayerItem(url: URL(string: self.streamUrl)!)
        
        if (player == nil) {
            player = AVPlayer(playerItem: playerItem)
            player.automaticallyWaitsToMinimizeStalling = true
            player.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), options: [.new], context: nil)
            runInBackground()
        } else {
            player.replaceCurrentItem(with: playerItem)
        }
        
        addInterruptionObserverIfNeed()
        
        setMetadata(title: title)
        self.streamImage = downloadAndSetImage(imageUrl: streamImageUrl)
        self.streamTitle = title
        
        let metaOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metaOutput.setDelegate(self, queue: DispatchQueue.main)
        playerItem.add(metaOutput)
    }
  
    private func resetStream() {
        playerItem = AVPlayerItem(url: URL(string: streamUrl)!)
        
        if (player == nil) {
            player = AVPlayer(playerItem: playerItem)
            player.automaticallyWaitsToMinimizeStalling = true
            player.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), options: [.new], context: nil)
            runInBackground()
        } else {
            player.replaceCurrentItem(with: playerItem)
        }

        // Set interruption handler.
        addInterruptionObserverIfNeed()
        
        let metaOutput = AVPlayerItemMetadataOutput(identifiers: nil)
        metaOutput.setDelegate(self, queue: DispatchQueue.main)
        playerItem.add(metaOutput)
        
    }
    
    private func addInterruptionObserverIfNeed(){
        if (!interruptionObserverAdded) {
            NotificationCenter.default.addObserver(self, selector: #selector(playerItemFailedToPlay), name: NSNotification.Name.AVPlayerItemFailedToPlayToEndTime, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
            interruptionObserverAdded = true
        }
    }
    
    private func setMetadata(title: String, track: String? = nil) {
        if isAvailableInControlCenter {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyArtist: title, MPMediaItemPropertyTitle: track ?? "", ]
        }
    }
    
    private func downloadAndSetImage(imageUrl: String) -> UIImage? {
        let newImage = downloadImage(imageUrl);
        if(isAvailableInControlCenter){
            setMetadataImage(newImage)
        }
        return newImage
    }
    
    private func setMetadataImage(_ image: UIImage?) {
        if( image == currentPlayerImage) {return}
        guard let currentPlayerImage = image else { return }
        
        let artwork = MPMediaItemArtwork(boundsSize: currentPlayerImage.size) { (size) -> UIImage in currentPlayerImage }
        MPNowPlayingInfoCenter.default().nowPlayingInfo?.updateValue(artwork, forKey: MPMediaItemPropertyArtwork)
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

    func play() {
        resetStream()
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
    
    func jsonToMap(_ jsonString: String) -> [String: Any] {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return [:]
        }
        do {
            if let jsonMap = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                return jsonMap
            }
        } catch {
            print("Ошибка парсинга JSON: \(error)")
        }
        return [:]
    }
    
    func strToJson(_ oldStr: String) -> String{
        var str = oldStr;
        str = str.replacingOccurrences(of: "\"", with: "'")
        str = str.replacingOccurrences(of: "{'", with: "{\"")
        str = str.replacingOccurrences(of: "''}", with: "\"}")
        str = str.replacingOccurrences(of: "None", with: "null")
        str = str.replacingOccurrences(of: "', '", with: "\", \"")
        str = str.replacingOccurrences(of: "': '", with: "\": \"")
        str = str.replacingOccurrences(of: "':", with: "\":")
        return str;
    }
    
    func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
                        from track: AVPlayerItemTrack?) {
        let metaDataItems = groups.first.map({ $0.items })
        let first = metaDataItems?.first
        guard let json = metaDataItems?.first?.stringValue else { return }
       
        print("trackData: \(strToJson(json))")
        let trackData = jsonToMap(strToJson(json));
      
        let title = trackData["title"] as? String ?? ""
        let artistTitle = trackData["artist"] as? String ?? ""
        let cover = trackData["cover"] as? String ?? ""
        
        updateTrackMetada(title: title, artistTitle: artistTitle, cover: cover)
    }
    
    private func updateTrackMetada(title: String, artistTitle: String, cover: String){
        // NOTIFY Flutter about meta
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "metadata"), object: nil, userInfo: ["metadata": [title, artistTitle, cover]])
        
        if !title.isEmpty, title != "unknown", !artistTitle.isEmpty, artistTitle != "unknown" {
            trackTitle = "\(title) - \(artistTitle)"
        } else {
            trackTitle = ""
        }
        
        if !cover.isEmpty, !cover.contains("defaultSongImage") {
            trackImage = downloadAndSetImage(imageUrl: cover)
        } else {
            trackImage = nil
        }
   
        setMetadata(title: streamTitle, track: trackTitle)
        setMetadataImage(trackImage ?? streamImage)
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
        setMetadataImage(trackImage ?? streamImage)
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
        removeTimeObserver()
        let interval = CMTimeMakeWithSeconds(seconds, preferredTimescale: 1)
        playerStopDate = Date(timeIntervalSinceNow: seconds)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval,
                                                      queue: .main) { [weak self] _ in
            guard let self = self else { return }
            guard let playerStopDate = self.playerStopDate else {
              self.removeTimeObserver()
              return
            }
            let secondsLeft = Date().timeIntervalSince(playerStopDate)
            if secondsLeft >= 0 {
                self.removeTimeObserver()
                self.stop()
            } else if abs(secondsLeft) < seconds / 2 {
                stopPlayer(after: abs(secondsLeft))
            }
        }
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
                setMetadataImage(streamImage)
            } else if status == .waitingToPlayAtSpecifiedRate {
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: "state"), object: nil, userInfo: ["state": true])
            }
        }
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
  
  private func removeTimeObserver() {
      playerStopDate = nil
      if let timeObserver = timeObserver {
          player.removeTimeObserver(timeObserver)
      }
      timeObserver = nil
  }
}
