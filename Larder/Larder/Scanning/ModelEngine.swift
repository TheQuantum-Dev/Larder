//
//  ModelEngine.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import CoreGraphics
import FoundationModels

@Generable
struct ModelFood {
    @Guide(description: "Generic name of the food or drink, singular, lowercase, no brand. Example: 'ketchup'")
    var name: String
}

@Generable
struct ModelScan {
    @Guide(description: "Distinct foods and drinks that are clearly visible in the photo.")
    var items: [ModelFood]
}

/// Asks Apple's on-device model to list what it sees. Image input only exists
/// on iOS 27 and later, and only where the model reports it can handle images,
/// so everything here is guarded and quietly returns nothing when it can't run.
enum ModelEngine {

    /// True when this device can send a photo to the on-device model.
    static var isSupported: Bool {
        if #available(iOS 27.0, macOS 27.0, *) {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else { return false }
            return model.capabilities.contains(.vision)
        }
        return false
    }

    /// Gets the model ready ahead of a scan. The first request after launch is
    /// noticeably slower, so call this when the person is about to scan.
    static func prewarm() {
        guard #available(iOS 27.0, macOS 27.0, *), isSupported else { return }
        LanguageModelSession(instructions: instructions).prewarm()
    }

    private static let instructions = """
        You list the food and drink items visible in a photo of a fridge or pantry. \
        Only report items you can genuinely see. If the photo shows no food, return an empty list.
        """

    /// Runs the model several times at once and returns each run's guesses.
    /// One run alone is unreliable, so the caller keeps only what repeats.
    /// Runs that fail (even after a retry) are left out; an empty result means
    /// "the model wasn't usable", not "nothing was found".
    static func runs(for image: CGImage, count: Int = 3) async -> [Set<ResolvedItem>] {
        guard #available(iOS 27.0, macOS 27.0, *), isSupported else { return [] }
        let scaled = image.downscaled(maxEdge: 1600)

        return await withTaskGroup(of: Set<ResolvedItem>?.self) { group in
            for _ in 0..<count {
                group.addTask { await singleRun(scaled) }
            }
            var results: [Set<ResolvedItem>] = []
            for await run in group {
                if let run { results.append(run) }
            }
            return results
        }
    }

    @available(iOS 27.0, macOS 27.0, *)
    private static func singleRun(_ image: CGImage) async -> Set<ResolvedItem>? {
        // Requests sometimes fail for a moment when several run together, so
        // each run gets one more try.
        for attempt in 0..<2 {
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(generating: ModelScan.self) {
                    "List every distinct food or drink you can see in this photo."
                    Attachment(image)
                }
                return Set(response.content.items.compactMap { IngredientCatalog.resolve($0.name) })
            } catch {
                if attempt == 0 { try? await Task.sleep(for: .milliseconds(600)) }
            }
        }
        return nil
    }
}
