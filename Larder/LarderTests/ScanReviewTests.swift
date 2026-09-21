//
//  ScanReviewTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/20/26.
//

import Testing
@testable import Larder

@MainActor
struct ScanReviewTests {
    private let egg = IngredientCatalog.resolve("egg")!
    private let milk = IngredientCatalog.resolve("milk")!
    private let banana = IngredientCatalog.resolve("banana")!
    private let rice = IngredientCatalog.resolve("rice")!

    private func review(right: [ResolvedItem] = [], maybe: [ResolvedItem] = []) -> ScanReview {
        let items = right.map { DetectedItem(item: $0, tier: .looksRight, votes: 3, runs: 3, hasVisionSupport: false) }
            + maybe.map { DetectedItem(item: $0, tier: .maybe, votes: 1, runs: 3, hasVisionSupport: false) }
        return ScanReview(result: ScanResult(items: items, usedModel: true))
    }

    @Test func looksRightStartsCheckedAndMaybeDoesNot() {
        let r = review(right: [egg], maybe: [banana])
        #expect(r.isChecked(egg))
        #expect(!r.isChecked(banana))
        #expect(r.selected == [egg])
    }

    @Test func togglingChecksAndUnchecks() {
        let r = review(right: [egg], maybe: [banana])
        r.toggle(banana)
        #expect(r.selected == [egg, banana])
        r.toggle(egg)
        #expect(r.selected == [banana])
    }

    @Test func addingSomethingNewListsItAndChecksIt() {
        let r = review(right: [egg])
        r.add(rice)
        #expect(r.added == [rice])
        #expect(r.selected == [egg, rice])
    }

    @Test func addingAnAlreadySuggestedItemJustChecksIt() {
        let r = review(right: [egg], maybe: [banana])
        r.add(banana)
        #expect(r.added.isEmpty)
        #expect(r.isChecked(banana))
    }

    @Test func addingTheSameThingTwiceDoesNotDuplicateIt() {
        let r = review()
        r.add(milk)
        r.add(milk)
        #expect(r.added == [milk])
    }

    @Test func aScanThatFoundNothingStillWorks() {
        let r = review()
        #expect(r.foundNothing)
        #expect(r.selected.isEmpty)
        r.add(egg)
        #expect(r.selected == [egg])
    }

    @Test func uncheckedHandAddedItemsStayListedButNotSelected() {
        let r = review()
        r.add(rice)
        r.toggle(rice)
        #expect(r.added == [rice])
        #expect(r.selected.isEmpty)
    }
}
