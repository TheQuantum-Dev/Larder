//
//  PantryScanner.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import CoreGraphics

nonisolated struct ScanResult {
    let items: [DetectedItem]
    /// Whether the on-device model took part, for choosing what to tell the user.
    let usedModel: Bool
}

/// Turns a photo into a tiered list of guesses. Vision always runs; the
/// model joins in where the device supports it. Either way the answer is a
/// starting point for the person to confirm, never the final word.
enum PantryScanner {
    /// Call when a scan is about to happen, so the first one is quicker.
    static func prewarm() {
        ModelEngine.prewarm()
    }

    static func scan(_ image: CGImage) async -> ScanResult {
        async let vision = VisionEngine.analyze(image)
        async let runs = ModelEngine.runs(for: image)

        let evidence = await vision
        let modelRuns = await runs
        let signals = ScanSignals(modelRuns: modelRuns,
                                  ocrHits: evidence.ocrHits,
                                  classifierScores: evidence.classifierScores)
        return ScanResult(items: ScanAggregator.aggregate(signals), usedModel: !modelRuns.isEmpty)
    }
}
