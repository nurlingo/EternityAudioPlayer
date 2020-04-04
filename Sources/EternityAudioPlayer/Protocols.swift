//
//  Protocols.swift
//  namaz
//
//  Created by Daniya on 01/03/2020.
//  Copyright © 2020 Nursultan Askarbekuly. All rights reserved.
//

import Foundation

//MARK:- Content Delegate

public protocol PlayerContentDelegate: class {
    func highlightPlaying(previousIndex: IndexPath, currentIndex: IndexPath)
    func scrollTo(_ indexPath: IndexPath)
    func didPause()
    func didContinue()
    func didCompleteAllTracks()
    func displayProgress(_ miliseconds: Int)
}

public extension PlayerContentDelegate {
    func highlightPlaying(previousIndex: IndexPath, currentIndex: IndexPath) {}
    func scrollTo(_ indexPath: IndexPath) {}
    func didPause() {}
    func didCompleteAllTracks() {}
    func didContinue() {}
    func displayProgress(_ miliseconds: Int) {}
}

//MARK:- Panel Delegate
public protocol PlayerPanelDelegate: class {
    func setPlayButton(_ imageName: String)
    func togglRepeatButton(_ mode: RepeatMode)
    func setSpeedButton(_ speed: String)
    func setProgress(_ progress: Float)
}

public extension PlayerPanelDelegate {
    func setPlayButton(_ imageName: String) {}
    func togglRepeatButton(_ activated: Bool) {}
    func setSpeedButton(_ speed: String) {}
    func setProgress(_ progress: Float) {}
}
