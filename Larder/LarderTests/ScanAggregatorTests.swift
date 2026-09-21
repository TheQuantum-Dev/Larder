//
//  ScanAggregatorTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/20/26.
//

import Testing
@testable import Larder

@MainActor
struct ScanAggregatorTests {
    private let egg = IngredientCatalog.resolve("egg")!
    private let milk = IngredientCatalog.resolve("milk")!
    private let banana = IngredientCatalog.resolve("banana")!

    private func tier(of item: ResolvedItem, in signals: ScanSignals) -> ScanTier? {
        ScanAggregator.aggregate(signals).first { $0.item == item }?.tier
    }

    // MARK: - With the model

    @Test func repeatedGuessesLookRight() {
        let signals = ScanSignals(modelRuns: [[egg, milk], [egg], [egg, banana]])
        #expect(tier(of: egg, in: signals) == .looksRight)
    }

    @Test func aGuessMadeOnceIsOnlyAMaybe() {
        let signals = ScanSignals(modelRuns: [[egg, banana], [egg], [egg]])
        #expect(tier(of: banana, in: signals) == .maybe)
    }

    @Test func aSingleGuessBackedByVisionLooksRight() {
        var signals = ScanSignals(modelRuns: [[banana], [], []])
        signals.classifierScores[banana] = 0.45
        #expect(tier(of: banana, in: signals) == .looksRight)

        var textBacked = ScanSignals(modelRuns: [[milk], [], []])
        textBacked.ocrHits = [milk]
        #expect(tier(of: milk, in: textBacked) == .looksRight)
    }

    @Test func aWeakLabelDoesNotBackUpAGuess() {
        var signals = ScanSignals(modelRuns: [[banana], [], []])
        signals.classifierScores[banana] = 0.1
        #expect(tier(of: banana, in: signals) == .maybe)
    }

    @Test func aStrongLabelAloneIsAMaybeWhenTheModelMissedIt() {
        var signals = ScanSignals(modelRuns: [[egg], [egg], [egg]])
        signals.classifierScores[banana] = 0.9
        #expect(tier(of: banana, in: signals) == .maybe)
        signals.classifierScores[milk] = 0.5
        #expect(tier(of: milk, in: signals) == nil)
    }

    @Test func textAloneIsNotEnoughWhenTheModelRan() {
        // Labels list ingredients ("contains milk"), so a text hit alone says little.
        var signals = ScanSignals(modelRuns: [[egg], [egg], [egg]])
        signals.ocrHits = [milk]
        #expect(tier(of: milk, in: signals) == nil)
    }

    @Test func whenOnlyOneRunSucceedsSingleGuessesAreNotRepeats() {
        let signals = ScanSignals(modelRuns: [[egg, banana]])
        #expect(tier(of: egg, in: signals) == .maybe)
    }

    // MARK: - Vision only (no model on this device)

    @Test func withoutTheModelAStrongLabelLooksRight() {
        var signals = ScanSignals()
        signals.classifierScores[banana] = 0.8
        signals.classifierScores[egg] = 0.5
        signals.classifierScores[milk] = 0.2
        #expect(tier(of: banana, in: signals) == .looksRight)
        #expect(tier(of: egg, in: signals) == .maybe)
        #expect(tier(of: milk, in: signals) == nil)
    }

    @Test func withoutTheModelReadTextIsAMaybe() {
        var signals = ScanSignals()
        signals.ocrHits = [milk]
        #expect(tier(of: milk, in: signals) == .maybe)
    }

    @Test func nothingDetectedGivesAnEmptyList() {
        #expect(ScanAggregator.aggregate(ScanSignals()).isEmpty)
    }

    // MARK: - Ordering

    @Test func looksRightComesBeforeMaybeAndMoreVotesComeFirst() {
        let signals = ScanSignals(modelRuns: [[egg, milk, banana], [egg, milk], [egg]])
        let result = ScanAggregator.aggregate(signals)
        #expect(result.map(\.item) == [egg, milk, banana])
        #expect(result.map(\.tier) == [.looksRight, .looksRight, .maybe])
    }
}
