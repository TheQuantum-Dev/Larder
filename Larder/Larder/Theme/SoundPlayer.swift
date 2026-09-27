//
//  SoundPlayer.swift
//  Larder
//
//  Created by Joshua Samuel on 9/22/26.
//

import AVFoundation
import UIKit

/// The app's sound effects, all original, made by Tools/sounds/make_sounds.py.
/// Everyday sounds are short and quiet (the tap is barely there, and only on
/// the big buttons); the celebrations are brighter and louder, and each big
/// moment has its own, so a goal doesn't sound like an unlock.
///
/// Plays through `.ambient`, which mixes with whatever else is playing and,
/// like any well-behaved UI sound effect, stays quiet when the ringer
/// switch is off.
enum SoundPlayer {
    private static var players: [String: AVAudioPlayer] = [:]
    private static var configuredSession = false

    /// The big pill buttons, and nothing else.
    static func tap() { play("Tap") }
    /// Something saved: the pantry updated, a change confirmed.
    static func pop() { play("Pop") }
    static func send() { play("Send") }
    static func receive() { play("Receive") }
    static func recordStart() { play("RecordStart") }
    static func recordStop() { play("RecordStop") }
    static func timerDone() { play("TimerDone") }
    /// Every "I made it".
    static func madeIt() { play("MadeIt") }
    /// The build-up, pop and settle that goes with the first meal ever made.
    static func firstMealCelebration() { play("FirstMeal") }
    /// A goal met or a streak milestone.
    static func congrats() { play("Congrats") }
    /// A new look for Nutmeg.
    static func unlock() { play("Unlock") }
    /// Joining Larder Plus.
    static func plusWelcome() { play("PlusWelcome") }

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
        for name in ["Tap", "Pop", "Send", "Receive", "TimerDone"] { _ = player(named: name) }
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
