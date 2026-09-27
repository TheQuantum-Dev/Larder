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
    /// How many of each item each run counted, where it could count them.
    var modelCounts: [[ResolvedItem: Int]] = []
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
    /// How many the model counted, when it could. Only ever a suggestion:
    /// Vision can't count, so phones without Apple Intelligence never set it.
    var count: Int? = nil

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
                detected.append(DetectedItem(item: candidate, tier: tier, votes: votes, runs: runCount,
                                             hasVisionSupport: supported,
                                             count: count(of: candidate, in: signals.modelCounts)))
            }
        }
        return sorted(detected)
    }

    /// The biggest count believed: counts above this are more likely a guess
    /// than a count.
    static let largestCount = 24

    /// The middle of what the runs counted, so one wild guess doesn't win.
    static func count(of item: ResolvedItem, in runs: [[ResolvedItem: Int]]) -> Int? {
        let counts = runs.compactMap { $0[item] }.filter { (1...largestCount).contains($0) }.sorted()
        guard !counts.isEmpty else { return nil }
        return counts[(counts.count - 1) / 2]
    }

    /// Puts several photos' results together. Each item keeps its best tier,
    /// and its biggest count rather than the sum, because two photos of the
    /// same shelf would otherwise count the same eggs twice.
    static func combine(_ results: [ScanResult]) -> ScanResult {
        var merged: [String: DetectedItem] = [:]
        for item in results.flatMap(\.items) {
            guard let current = merged[item.id] else {
                merged[item.id] = item
                continue
            }
            let counts = [current.count, item.count].compactMap { $0 }
            merged[item.id] = DetectedItem(item: current.item, tier: min(current.tier, item.tier),
                                           votes: max(current.votes, item.votes), runs: max(current.runs, item.runs),
                                           hasVisionSupport: current.hasVisionSupport || item.hasVisionSupport,
                                           count: counts.max())
        }
        return ScanResult(items: sorted(Array(merged.values)), usedModel: results.contains(where: \.usedModel))
    }

    private static func sorted(_ detected: [DetectedItem]) -> [DetectedItem] {
        detected.sorted {
            if $0.tier != $1.tier { return $0.tier < $1.tier }
            if $0.votes != $1.votes { return $0.votes > $1.votes }
            return $0.item.name < $1.item.name
        }
    }
}
