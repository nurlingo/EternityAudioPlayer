//
//  AudioPlayer.swift
//  namaz
//
//  Created by Daniya on 11/01/2020.
//  Copyright © 2020 Nursultan Askarbekuly. All rights reserved.
//

import UIKit
import AVFoundation

public enum ButtonIcon: String {
    case play = "play"
    case pause = "pause"
    case speedometer
    case forward
    case backward
    case repeatOne = "repeat.1"
    case repeatAll
    case repeatOff
}

public enum ProgressMode {
    case sectionBased
    case rowBased
    case durationBased
}

public enum RepeatMode: Int {
    case repeatOff = 1
    case repeatAll = 2
//    case repeatOne = 3
}

// AudioPlayer functionality
public class AudioPlayer: NSObject {
    
    public static let shared = AudioPlayer()
    
    public var progressMode: ProgressMode = .durationBased {
        didSet {
            if progressMode == .durationBased {
                setupDurationTracking()
            } else {
                removeDurationTracking()
            }
        }
    }
    
    public var repeatMode: RepeatMode = .repeatOff
    
    public weak var panelDelegate: PlayerPanelDelegate?
    public weak var contentDelegate: PlayerContentDelegate? {
        didSet {
            if player?.isPlaying ?? false {
                contentDelegate?.highlightPlaying(previousIndex: previousIndex, currentIndex: audioIndex)
                contentDelegate?.scrollTo(audioIndex)
            }
            
        }
    }
    
    public var tracks: [[String]] = []
    public var playSpeed: Float = 1.0 {
        didSet {
            UserDefaults.standard.set(playSpeed, forKey: "playSpeed")
            UserDefaults.standard.synchronize()
        }
    }
    
    public var audioIndex: IndexPath = IndexPath(row: 0, section: 0) {
        
        willSet {
            previousIndex = audioIndex
        }
        
        didSet {
            contentDelegate?.highlightPlaying(previousIndex: previousIndex, currentIndex: audioIndex)
            /// Uncomment for progress by tracks played
            if progressMode == .sectionBased {
                panelDelegate?.setProgress(Float(audioIndex.section)/Float(tracks.count-1))
            } else if progressMode == .rowBased {
                let allTracks = tracks.flatMap{ $0 }
                if let currentlyPlayingIndex = allTracks.firstIndex(of: tracks[audioIndex.section][audioIndex.row]) {
                    panelDelegate?.setProgress(Float(currentlyPlayingIndex)/Float(allTracks.count-1))
                }
            }
            
            self.playAudio()
            contentDelegate?.scrollTo(audioIndex)
        }
    }
    
    fileprivate var previousIndex: IndexPath = IndexPath(row: 0, section: 0)
    fileprivate var player: AVAudioPlayer?
    fileprivate var updater : CADisplayLink! = nil
    
    override init() {
        super.init()
        setupPlayer()
        registerForInterruptions()
    }
    
    public func deinitializePlayer() {
        audioIndex = IndexPath(row: 0, section: 0)
        repeatMode = .repeatOff
        progressMode = .durationBased
        player?.stop()
        player = nil
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
    }
    
    fileprivate func setupDurationTracking() {
        updater = CADisplayLink(target: self, selector: #selector(self.trackAudio))
        updater.add(to: RunLoop.current, forMode: RunLoop.Mode.common)
    }
    
    fileprivate func removeDurationTracking() {
        updater = nil
    }
    
    @objc fileprivate func trackAudio() {
        
        let current: Float = Float(player?.currentTime ?? 0.0)
        contentDelegate?.displayProgress(Int(current * 10))
        
        let duration: Float = Float(player?.duration ?? 1.0)
        let progress = current / duration
        panelDelegate?.setProgress(progress)
    }
    
    deinit {
        updater = nil
    }
    
    fileprivate func setupPlayer() {
        if let playSpeedValue = UserDefaults.standard.object(forKey: "playSpeed") as? Float {
            self.playSpeed = playSpeedValue
            panelDelegate?.setSpeedButton("\(playSpeedValue)")
        } else {
            UserDefaults.standard.set(playSpeed, forKey: "playSpeed")
            UserDefaults.standard.synchronize()
        }
        
        do {
            // play sound even on silent
            if #available(iOS 10.0, *) {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
            } else {
                AVAudioSession.sharedInstance().perform(NSSelectorFromString("setCategory:error:"), with: AVAudioSession.Category.playback)
            }
            
        } catch let error as NSError {
            print(#function, error.description)
        }
    }
    
    fileprivate func registerForInterruptions() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(handleInterruption),
                                       name: AVAudioSession.interruptionNotification,
                                       object: nil)
    }
    
    @objc fileprivate func handleInterruption(notification: Notification) {
        // put the player to pause in case of an interruption (e.g. incoming phone call)
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
        }
        if type == .began {
            pausePlayer()
            panelDelegate?.setPlayButton(ButtonIcon.play.rawValue)
        }
        
    }
    
}

extension AudioPlayer {
    
    private func pausePlayer() {
        contentDelegate?.didPause()
        self.player?.pause()
    }
    
    public func handlePlayButton() {
        guard let player = player else {
            self.audioIndex.row = self.audioIndex.row
            return
        }
        
        if player.isPlaying {
            pausePlayer()
            panelDelegate?.setPlayButton(ButtonIcon.play.rawValue)
        } else {
            contentDelegate?.didContinue()
            player.play()
            panelDelegate?.setPlayButton(ButtonIcon.pause.rawValue)
        }
    }
    
    public func handleNextButton() {
        goToNextLine()
    }
    
    public func handlePreviousButton() {
        if audioIndex.row > 0 {
            audioIndex.row -= 1
        } else if audioIndex.section > 0 {
            
            let prevComponentItems = tracks[audioIndex.section - 1]
            audioIndex = IndexPath(row: prevComponentItems.count-1, section: audioIndex.section - 1)
        } else {
            audioIndex.row = 0
        }
    }
    
    public func handleRepeatButton() {
        let newValue = (repeatMode.rawValue % 3) + 1
        repeatMode = RepeatMode(rawValue: newValue) ?? .repeatOff
        
        switch repeatMode {
        case .repeatOff:
            panelDelegate?.setRepeatButton(ButtonIcon.repeatOff.rawValue)
        case .repeatAll:
            panelDelegate?.setRepeatButton(ButtonIcon.repeatAll.rawValue)
//        case .repeatOne:
//            panelDelegate?.setRepeatButton(ButtonIcon.repeatOne.rawValue)
        }
        
    }
    
    public func handleSpeedButton() {
        switch playSpeed {
        case 1.0:
            playSpeed = 1.25
            panelDelegate?.setSpeedButton("1.2")
        case 1.25:
            playSpeed = 1.5
            panelDelegate?.setSpeedButton("1.5")
        case 1.5:
            playSpeed = 2.0
            panelDelegate?.setSpeedButton("2.0")
        default:
            playSpeed = 1.0
            panelDelegate?.setSpeedButton("1.0")
        }
        
        if let player = player, player.isPlaying {
            
            player.stop()
            
            
            /// if volume is ON, limit playspeed to 1.75
            let isVolumeOn = AVAudioSession.sharedInstance().outputVolume > 0
            player.rate = isVolumeOn ? min(playSpeed, 1.75) : playSpeed
            
            player.prepareToPlay()
            player.play()
        }
    }
    
    public func play(at indexPath: IndexPath) {
        audioIndex = indexPath
    }
    
}

/// AudioPlayer functionality
extension AudioPlayer: AVAudioPlayerDelegate {
    
    private func playAudio() {
        
        let currentSection = tracks[audioIndex.section]
        let currentTrack = currentSection[audioIndex.row]
        
        guard !currentTrack.isEmpty, let path = Bundle.main.path(forResource: currentTrack, ofType: "mp3") else {
            return
        }
        
        let url = URL(fileURLWithPath: path)
        player = nil
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            guard let player = player else { return }
            player.delegate = self
            player.enableRate = true
            
            /// if output volume is ON, limit playspeed to 1.75 (specific to namazapp)
            let isVolumeOn = AVAudioSession.sharedInstance().outputVolume > 0
            player.rate = isVolumeOn ? min(playSpeed, 1.75) : playSpeed
            
            
            player.prepareToPlay()
            player.play()
            panelDelegate?.setPlayButton(ButtonIcon.pause.rawValue)
        } catch let error as NSError {
            print(#function, error.description)
        }
        
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        switch repeatMode {
        case .repeatOff:
            goToNextLine()
        case .repeatAll:
            playRepeat()
//        case .repeatOne:
//            audioIndex.row = audioIndex.row
        }
    }
    
    private func playRepeat() {
        let section = tracks[audioIndex.section]
        let moreRowsAhead = audioIndex.row < section.count - 1
        
        if moreRowsAhead {
            self.audioIndex.row += 1
        } else {
            self.audioIndex.row = 0
        }
    }
    
    private func goToNextLine(){
        
        let moreSectionsAhead = audioIndex.section < tracks.count - 1
        let section = tracks[audioIndex.section]
        let moreRowsAhead = audioIndex.row < section.count - 1
        
        if moreRowsAhead {
            self.audioIndex.row += 1
        } else if moreSectionsAhead {
            self.audioIndex = IndexPath(row: 0, section: self.audioIndex.section + 1)
        } else {
            self.contentDelegate?.didCompleteAllTracks()
            self.panelDelegate?.setPlayButton(ButtonIcon.play.rawValue)
        }
    }
    
}
