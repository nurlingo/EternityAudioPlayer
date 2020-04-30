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
                contentDelegate?.highlightPlaying(previousIndex: previousIndex, currentIndex: currentIndex)
                contentDelegate?.scrollTo(currentIndex)
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
    
    private var previousIndex: IndexPath = IndexPath(row: 0, section: 0)
    
    private var currentIndex: IndexPath = IndexPath(row: 0, section: 0) {
        willSet {
            previousIndex = currentIndex
        }
    }
    
    private var lastRowPreviousSection: IndexPath {
        IndexPath(row: tracks[currentIndex.section - 1].count-1, section: currentIndex.section - 1)
    }
    
    private var previousRowSameSection: IndexPath {
        IndexPath(row: currentIndex.row-1, section: currentIndex.section)
    }
    
    private var firstRowSameSection: IndexPath {
        IndexPath(row: 0, section: currentIndex.section)
    }
    
    private var firstRowNextSection: IndexPath {
        IndexPath(row: 0, section: currentIndex.section+1)
    }
    
    private var nextRowSameSection: IndexPath {
        IndexPath(row: currentIndex.row+1, section: currentIndex.section)
    }
    
    fileprivate var player: AVAudioPlayer?
    fileprivate var updater : CADisplayLink! = nil
    
    override init() {
        super.init()
        setupPlayer()
        registerForInterruptions()
    }
    
    public func play(at indexPath: IndexPath) {
        
        self.currentIndex = indexPath
        
        contentDelegate?.highlightPlaying(previousIndex: previousIndex, currentIndex: currentIndex)
        /// Uncomment for progress by tracks played
        if progressMode == .sectionBased {
            panelDelegate?.setProgress(Float(currentIndex.section)/Float(tracks.count-1))
        } else if progressMode == .rowBased {
            let allTracks = tracks.flatMap{ $0 }
            if let currentlyPlayingIndex = allTracks.firstIndex(of: tracks[currentIndex.section][currentIndex.row]) {
                panelDelegate?.setProgress(Float(currentlyPlayingIndex)/Float(allTracks.count-1))
            }
        }
        
        self.playAudio()
        contentDelegate?.scrollTo(currentIndex)
    }
    
    public func deinitializePlayer() {
        resetPlayer()
        repeatMode = .repeatOff
        progressMode = .durationBased
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
    }
    
    private func resetPlayer() {
        currentIndex = IndexPath(row: 0, section: 0)
        player?.stop()
        player = nil
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
            self.play(at: self.currentIndex)
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
        if currentIndex.row > 0 {
            play(at: previousRowSameSection)
        } else if currentIndex.section > 0 {
            play(at: lastRowPreviousSection)
        } else {
            play(at: firstRowSameSection)
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
    
}

/// AudioPlayer functionality
extension AudioPlayer: AVAudioPlayerDelegate {
    
    private func playAudio() {
        
        let currentSection = tracks[currentIndex.section]
        let currentTrack = currentSection[currentIndex.row]
        
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
//            play(at: audioIndex)
        }
    }
    
    private func playRepeat() {
        let section = tracks[currentIndex.section]
        let moreRowsAhead = currentIndex.row < section.count - 1
        
        if moreRowsAhead {
            self.play(at: nextRowSameSection)
        } else {
            self.play(at: firstRowSameSection)
        }
    }
    
    private func goToNextLine(){
        
        let moreSectionsAhead = currentIndex.section < tracks.count - 1
        let section = tracks[currentIndex.section]
        let moreRowsAhead = currentIndex.row < section.count - 1
        
        if moreRowsAhead {
            self.play(at: nextRowSameSection)
        } else if moreSectionsAhead {
            self.play(at: firstRowNextSection)
        } else {
            self.contentDelegate?.didCompleteAllTracks()
            self.panelDelegate?.setPlayButton(ButtonIcon.play.rawValue)
            self.resetPlayer()
        }
    }
    
}
