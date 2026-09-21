//
//  VisionEngine.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import CoreGraphics
import Vision

/// What Apple's Vision framework can tell us about a photo. It runs on every
/// device, with no Apple Intelligence needed, so it's both the fallback scan
/// and the evidence used to check the model's guesses.
nonisolated struct VisionEvidence {
    var ocrHits: Set<ResolvedItem> = []
    var classifierScores: [ResolvedItem: Double] = [:]
}

enum VisionEngine {
    static func analyze(_ image: CGImage) async -> VisionEvidence {
        async let text = readText(in: image)
        async let labels = classify(image)
        return VisionEvidence(ocrHits: await text, classifierScores: await labels)
    }

    /// Reads any printed text and looks for ingredient names in it.
    private static func readText(in image: CGImage) async -> Set<ResolvedItem> {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        guard let observations = try? await request.perform(on: image) else { return [] }
        let text = observations
            .compactMap { $0.topCandidates(1).first }
            .filter { $0.confidence >= 0.5 }
            .map(\.string)
            .joined(separator: "\n")
        return IngredientCatalog.find(inText: text)
    }

    /// Classifies the whole photo and each cell of a 3 by 3 grid, so a shelf
    /// with many items has a chance to be seen item by item. Keeps the best
    /// confidence per ingredient.
    private static func classify(_ image: CGImage) async -> [ResolvedItem: Double] {
        var best: [ResolvedItem: Double] = [:]
        for piece in [image] + image.tiles(grid: 3) {
            let request = ClassifyImageRequest()
            guard let observations = try? await request.perform(on: piece) else { continue }
            for observation in observations where observation.confidence >= 0.2 {
                let label = observation.identifier.replacingOccurrences(of: "_", with: " ")
                // Only labels that are ingredients count; "container" or
                // "refrigerator" resolve to nothing useful.
                guard let item = IngredientCatalog.resolve(label), !item.isCustom else { continue }
                best[item] = max(best[item] ?? 0, Double(observation.confidence))
            }
        }
        return best
    }
}
