//
//  SoundPlayer.swift
//  Larder
//
//  Created by Joshua Samuel on 9/22/26.
//

import AVFoundation
import UIKit

/// Three short, original sound effects that go alongside the app's haptics:
/// a tap, a warm success chime, and a timer alert. Simple placeholder tones
/// for now — worth a real sound pass later, but they give every tap and
/// celebration something to be heard as well as felt.
///
/// Plays through `.ambient`, which mixes with whatever else is playing and,
/// like any well-behaved UI sound effect, stays quiet when the ringer
/// switch is off.
enum SoundPlayer {
    private static var players: [String: AVAudioPlayer] = [:]
    private static var configuredSession = false

    static func tap() { play("Tap") }
    static func success() { play("Success") }
    static func timerDone() { play("TimerDone") }

    private static func play(_ name: String) {
        configureSessionIfNeeded()
        guard let player = player(named: name) else { return }
        player.currentTime = 0
        player.play()
    }

    private static func player(named name: String) -> AVAudioPlayer? {
        if let existing = players[name] { return existing }
        guard let data = NSDataAsset(name: name)?.data,
              let player = try? AVAudioPlayer(data: data) else { return nil }
        player.prepareToPlay()
        players[name] = player
        return player
    }

    private static func configureSessionIfNeeded() {
        guard !configuredSession else { return }
        configuredSession = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
