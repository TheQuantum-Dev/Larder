//
//  TimerAlarm.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import AVFoundation
import UIKit

/// The ring when a Cook Mode timer runs out. Unlike the app's other sounds it
/// keeps going until someone taps Stop, and it rings with the silent switch
/// on, the same as the Clock app's timer: it's an alarm you set on purpose.
@MainActor
final class TimerAlarm {
    static let shared = TimerAlarm()

    private var player: AVAudioPlayer?
    private var buzz: Timer?

    private(set) var isRinging = false

    func start() {
        guard !isRinging else { return }
        isRinging = true
        // `.playback` is what lets it ring on silent. Other audio ducks
        // under it instead of stopping.
        let audio = AVAudioSession.sharedInstance()
        try? audio.setCategory(.playback, options: [.duckOthers])
        try? audio.setActive(true)
        if player == nil, let data = NSDataAsset(name: "TimerAlarm")?.data {
            player = try? AVAudioPlayer(data: data)
            player?.numberOfLoops = -1
        }
        player?.currentTime = 0
        player?.play()

        let haptic = UINotificationFeedbackGenerator()
        haptic.notificationOccurred(.warning)
        buzz = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { @MainActor in haptic.notificationOccurred(.warning) }
        }
    }

    func stop() {
        guard isRinging else { return }
        isRinging = false
        player?.stop()
        buzz?.invalidate()
        buzz = nil
        // Let whatever was ducked come back up, then return to the everyday
        // setup that respects the silent switch.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        SoundPlayer.useAmbientSession()
    }
}
