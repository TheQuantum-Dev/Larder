//
//  LivelyNutmeg.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import SwiftUI

/// Small moves worked out from the clock, shared by every lively Nutmeg.
nonisolated enum NutmegMotion {
    /// A smooth 0-1-0 bump lasting `lasting` seconds, once every `every` seconds.
    static func pulse(_ t: Double, every: Double, lasting: Double) -> Double {
        let phase = t.truncatingRemainder(dividingBy: every)
        guard phase >= 0, phase < lasting else { return 0 }
        return sin(phase / lasting * .pi)
    }

    /// Blinks at uneven times (two rhythms that rarely line up), with the odd
    /// double blink, so it never looks mechanical.
    static func blink(_ t: Double) -> Double {
        max(pulse(t, every: 4.3, lasting: 0.16),
            pulse(t + 1.9, every: 6.7, lasting: 0.16),
            pulse(t + 0.3, every: 13.1, lasting: 0.16))
    }

    /// Now and then a slow look to one side and back, alternating sides.
    static func glance(_ t: Double) -> CGSize {
        let amount = pulse(t + 2, every: 9.5, lasting: 2.4)
        let side: CGFloat = Int((t + 2) / 9.5).isMultiple(of: 2) ? 1 : -1
        return CGSize(width: side * 12 * amount, height: -3 * amount)
    }

    /// A small, occasional head tilt, in degrees.
    static func tilt(_ t: Double) -> Double {
        pulse(t + 5, every: 11.3, lasting: 1.6) * 4
    }
}

/// Nutmeg with a bit of life: he blinks, glances around now and then, and
/// tilts his head a little. Everything is slow and small, never staring or
/// following anyone, and it all stops for Reduce Motion.
struct LivelyNutmeg: View {
    var mood = NutmegView.Mood.idle
    var pose = NutmegView.Pose.noHands
    var expression = NutmegView.Expression.smile
    var cheer = 0
    var nod = 0
    /// How far his eyelids droop (0 wide awake, 0.4 sleepy).
    var sleepy = 0.0
    /// Offsets the rhythm, so two Nutmegs on one screen don't blink together.
    var seed = 0.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate + seed
            let still = reduceMotion
            NutmegView(mood: mood, pose: pose, nod: nod, cheer: cheer,
                       gaze: still ? .zero : NutmegMotion.glance(t),
                       eyelids: still ? sleepy : max(sleepy, NutmegMotion.blink(t)),
                       expression: expression)
                .rotationEffect(.degrees(still ? 0 : NutmegMotion.tilt(t)), anchor: .bottom)
        }
    }
}
