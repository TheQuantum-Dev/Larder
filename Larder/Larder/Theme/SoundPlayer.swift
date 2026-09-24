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
    /// The build-up, pop and settle that goes with the first meal ever made.
    static func firstMealCelebration() { play("FirstMeal") }

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

    /// Called once at launch: sets up the audio session and loads the sounds
    /// away from the main thread, so the first tap never waits on audio.
    static func prepare() {
        configureSessionIfNeeded()
        for name in ["Tap", "Success", "TimerDone", "FirstMeal"] { _ = player(named: name) }
    }

    private static func configureSessionIfNeeded() {
        guard !configuredSession else { return }
        configuredSession = true
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        // Activating is the slow part; doing it here, off the main thread,
        // means play() never has to.
        DispatchQueue.global(qos: .utility).async {
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }
}
