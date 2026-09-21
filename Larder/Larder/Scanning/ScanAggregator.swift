//
//  ScanAggregator.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation

/// Everything the engines noticed in one photo, before any judgment is made.
nonisolated struct ScanSignals {
    /// One set of guessed items per successful model run.
    var modelRuns: [Set<ResolvedItem>] = []
    /// Ingredients whose names appear in text read off the photo.
    var ocrHits: Set<ResolvedItem> = []
    /// The image classifier's best confidence for each ingredient, 0 to 1.
    var classifierScores: [ResolvedItem: Double] = [:]
}

nonisolated enum ScanTier: Int, Comparable, Sendable {
    case looksRight = 0
    case maybe = 1

    static func < (lhs: ScanTier, rhs: ScanTier) -> Bool { lhs.rawValue < rhs.rawValue }
}

nonisolated struct DetectedItem: Identifiable, Hashable, Sendable {
    let item: ResolvedItem
    let tier: ScanTier
    /// How many model runs named it, out of `runs`.
    let votes: Int
    let runs: Int
    let hasVisionSupport: Bool

    var id: String { item.id }
}

/// Decides how much to trust each guess. The model invents things, so a guess
/// only counts as "Looks right" when it's repeated across runs or backed by
/// what Vision saw in the photo. Everything else stays a "Maybe".
nonisolated enum ScanAggregator {
    /// A classifier label this strong backs up a model guess.
    static let corroboratingScore = 0.3
    /// A classifier label this strong is worth showing even if the model missed it.
    static let standaloneScore = 0.7
    /// Without the model, the classifier is all we have, so the bars change.
    static let baselineLooksRight = 0.75
    static let baselineMaybe = 0.4

    static func aggregate(_ signals: ScanSignals) -> [DetectedItem] {
        let runCount = signals.modelRuns.count
        var candidates = Set(signals.modelRuns.flatMap { $0 })
        candidates.formUnion(signals.classifierScores.keys)
        candidates.formUnion(signals.ocrHits)

        var detected: [DetectedItem] = []
        for candidate in candidates {
            let votes = signals.modelRuns.filter { $0.contains(candidate) }.count
            let score = signals.classifierScores[candidate] ?? 0
            let read = signals.ocrHits.contains(candidate)
            let supported = read || score >= corroboratingScore

            let tier: ScanTier?
            if runCount >= 2 {
                if votes >= 2 || (votes >= 1 && supported) { tier = .looksRight }
                else if votes == 1 || score >= standaloneScore { tier = .maybe }
                else { tier = nil }
            } else if runCount == 1 {
                if votes == 1 && supported { tier = .looksRight }
                else if votes == 1 || score >= standaloneScore { tier = .maybe }
                else { tier = nil }
            } else {
                if score >= baselineLooksRight { tier = .looksRight }
                else if score >= baselineMaybe || read { tier = .maybe }
                else { tier = nil }
            }

            if let tier {
                detected.append(DetectedItem(item: candidate, tier: tier, votes: votes,
                                             runs: runCount, hasVisionSupport: supported))
            }
        }

        return detected.sorted {
            if $0.tier != $1.tier { return $0.tier < $1.tier }
            if $0.votes != $1.votes { return $0.votes > $1.votes }
            return $0.item.name < $1.item.name
        }
    }
}
