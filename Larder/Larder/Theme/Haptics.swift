//
//  Haptics.swift
//  Larder
//
//  Created by Joshua Samuel on 9/22/26.
//

import CoreHaptics

/// A one-off custom haptic for the biggest moment in the app: the first meal
/// ever finished. A plain system pattern doesn't have room for a build-up, so
/// this drives Core Haptics directly — a swell, a peak right as the confetti
/// lets go, then a settle. Every meal after this one goes back to the plain,
/// simpler thump.
enum Haptics {
    /// How long the swell takes to reach its peak. The confetti and the
    /// matching sound are both timed to start exactly here.
    static let firstMealBuildUp: TimeInterval = 0.55

    private static var engine: CHHapticEngine?

    static func firstMealCelebration() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine = try currentEngine()
            let player = try engine.makePlayer(with: try pattern())
            try player.start(atTime: 0)
        } catch {
            // A missed haptic is never worth crashing over.
        }
    }

    private static func currentEngine() throws -> CHHapticEngine {
        if let engine { return engine }
        let engine = try CHHapticEngine()
        engine.resetHandler = { try? engine.start() }
        engine.stoppedHandler = { _ in }
        try engine.start()
        Self.engine = engine
        return engine
    }

    /// Build → peak → settle, as one pattern: a low hum that climbs for
    /// `firstMealBuildUp` seconds, a sharp pop right at the top, then a
    /// softer buzz that fades back to nothing.
    private static func pattern() throws -> CHHapticPattern {
        let buildUp = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)],
            relativeTime: 0, duration: firstMealBuildUp)
        let buildUpCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 0.15),
                CHHapticParameterCurve.ControlPoint(relativeTime: firstMealBuildUp, value: 1.0),
            ],
            relativeTime: 0)

        let peak = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)],
            relativeTime: firstMealBuildUp)

        let settleStart = firstMealBuildUp + 0.08
        let settleDuration = 0.5
        let settle = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)],
            relativeTime: settleStart, duration: settleDuration)
        let settleCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 0.9),
                CHHapticParameterCurve.ControlPoint(relativeTime: settleDuration, value: 0.0),
            ],
            relativeTime: settleStart)

        return try CHHapticPattern(events: [buildUp, peak, settle],
                                   parameterCurves: [buildUpCurve, settleCurve])
    }
}
