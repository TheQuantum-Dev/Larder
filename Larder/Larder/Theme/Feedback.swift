//
//  Feedback.swift
//  Larder
//
//  Created by Joshua Samuel on 9/22/26.
//

import SwiftUI

extension SensoryFeedback {
    /// The app's everyday tap: a light but firm impact, one notch stronger
    /// than the system's own `.selection`, which reads as too soft on
    /// device. Every quiz tap, chip toggle and button press uses this one
    /// pattern, so tuning it here tunes it everywhere.
    static var appTap: SensoryFeedback { .impact(weight: .light, intensity: 1.0) }
}

extension View {
    /// The standard tap: a firm haptic plus a short click, together. Used
    /// wherever a selection or toggle happens.
    func tapFeedback<T: Equatable>(_ trigger: T) -> some View {
        self
            .sensoryFeedback(.appTap, trigger: trigger)
            .onChange(of: trigger) { _, _ in SoundPlayer.tap() }
    }
}
