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
    /// The standard tap: a firm haptic, used wherever a selection or toggle
    /// happens. It's felt, not heard: a click on every chip and stepper got
    /// tiresome, so only the big pill buttons make a sound.
    func tapFeedback<T: Equatable>(_ trigger: T) -> some View {
        sensoryFeedback(.appTap, trigger: trigger)
    }
}
