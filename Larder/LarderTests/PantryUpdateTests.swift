//
//  PantryUpdateTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/26/26.
//

import CoreGraphics
import Testing
@testable import Larder

private let egg = IngredientCatalog.resolve("egg")!
private let milk = IngredientCatalog.resolve("milk")!
private let rice = IngredientCatalog.resolve("rice")!
private let onion = IngredientCatalog.resolve("onion")!
private let bread = IngredientCatalog.resolve("bread")!

private func found(_ item: ResolvedItem, _ tier: ScanTier = .looksRight, count: Int? = nil) -> DetectedItem {
    DetectedItem(item: item, tier: tier, votes: tier == .looksRight ? 3 : 1, runs: 3, hasVisionSupport: false, count: count)
}

private func tinyImage() -> CGImage {
    let context = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    return context.makeImage()!
}

struct ScanCombineTests {
    @Test func eachItemKeepsItsBestTierAcrossPhotos() {
        let first = ScanResult(items: [found(egg, .maybe), found(milk)], usedModel: false)
        let second = ScanResult(items: [found(egg), found(onion, .maybe)], usedModel: true)
        let combined = ScanAggregator.combine([first, second])
        #expect(combined.items.count == 3)
        #expect(combined.items.first { $0.item == egg }?.tier == .looksRight)
        #expect(combined.usedModel)
    }

    @Test func countsTakeTheBiggestNotTheSum() {
        // Two photos of the same shelf shouldn't count the same eggs twice.
        let combined = ScanAggregator.combine([ScanResult(items: [found(egg, count: 4)], usedModel: true),
                                               ScanResult(items: [found(egg, count: 6)], usedModel: true)])
        #expect(combined.items.first?.count == 6)
    }

    @Test func theCountIsTheMiddleOfWhatTheRunsSaid() {
        let runs: [[ResolvedItem: Int]] = [[egg: 6], [egg: 5], [egg: 40], [:]]
        #expect(ScanAggregator.count(of: egg, in: runs) == 5)
        #expect(ScanAggregator.count(of: milk, in: runs) == nil)
        // A silly count on its own is dropped rather than believed.
        #expect(ScanAggregator.count(of: egg, in: [[egg: 99]]) == nil)
    }

    @Test func aggregatingPassesTheCountThrough() {
        let signals = ScanSignals(modelRuns: [[egg], [egg], [egg]], modelCounts: [[egg: 3], [egg: 2], [egg: 3]])
        #expect(ScanAggregator.aggregate(signals).first?.count == 3)
    }
}

@MainActor
struct ScanQueueTests {
    @Test func photosAreLookedAtOneAtATimeInOrder() async {
        var order: [Int] = []
        var running = 0
        var mostAtOnce = 0
        var next = 0
        let queue = ScanQueue { _ in
            let mine = next
            next += 1
            running += 1
            mostAtOnce = max(mostAtOnce, running)
            try? await Task.sleep(for: .milliseconds(20))
            running -= 1
            order.append(mine)
            return ScanResult(items: [found(egg)], usedModel: false)
        }
        queue.add(tinyImage())
        queue.add(tinyImage())
        queue.add(tinyImage())
        #expect(!queue.isDone)
        await queue.waitUntilDone()
        #expect(queue.isDone)
        #expect(order == [0, 1, 2])
        #expect(mostAtOnce == 1)
        #expect(queue.finishedCount == 3)
    }

    @Test func aPhotoAddedLaterIsPickedUpToo() async {
        let queue = ScanQueue { _ in ScanResult(items: [found(milk)], usedModel: false) }
        queue.add(tinyImage())
        await queue.waitUntilDone()
        queue.add(tinyImage())
        await queue.waitUntilDone()
        #expect(queue.finishedCount == 2)
        #expect(queue.combined.items.map(\.item) == [milk])
    }

    @Test func thereIsALimit() {
        let queue = ScanQueue { _ in
            try? await Task.sleep(for: .seconds(5))
            return ScanResult(items: [], usedModel: false)
        }
        for _ in 0..<(ScanQueue.limit + 2) { queue.add(tinyImage()) }
        #expect(queue.shots.count == ScanQueue.limit)
        #expect(queue.isFull)
        queue.cancel()
        #expect(queue.shots.isEmpty)
    }
}

@MainActor
struct PantryUpdateTests {
    private let pantry = [
        PantrySnapshot(item: egg, quantity: 6, unit: .items),
        PantrySnapshot(item: milk),
        PantrySnapshot(item: rice, quantity: 500, unit: .grams),
        PantrySnapshot(item: bread, quantity: 1, unit: .bags),
    ]

    private func review(_ items: [DetectedItem]) -> ScanReview {
        ScanReview(result: ScanResult(items: items, usedModel: true), pantry: pantry)
    }

    @Test func thingsAlreadyThereAreCheckedNotAddedAgain() {
        let r = review([found(egg), found(onion), found(milk, .maybe)])
        #expect(r.looksRight == [onion])
        #expect(r.maybe.isEmpty)
        #expect(r.alreadyHave.map(\.id) == ["egg", "milk"])
        #expect(r.notSpotted.map(\.id) == ["rice", "bread"])
        #expect(r.update == PantryUpdate(add: [onion]))
    }

    @Test func aCountFromThePhotoIsAMarkedSuggestion() {
        let r = review([found(egg, count: 2)])
        #expect(r.amount(for: "egg") == 2)
        #expect(r.isGuess("egg"))
        #expect(r.update.amounts == ["egg": 2])
        // Touching the stepper makes it the person's own number.
        r.step("egg", by: 1)
        #expect(r.amount(for: "egg") == 3)
        #expect(!r.isGuess("egg"))
    }

    @Test func weighedThingsIgnoreCountsAndSteps() {
        let r = review([found(rice, count: 3)])
        #expect(r.amount(for: "rice") == 500)
        r.step("rice", by: -1)
        #expect(r.update.isEmpty)
    }

    @Test func steppingFromSomeStartsAtOneOrNone() {
        let r = review([found(milk)])
        #expect(r.amount(for: "milk") == nil)
        r.step("milk", by: 1)
        #expect(r.update.amounts == ["milk": 1])
        let other = review([found(milk)])
        other.step("milk", by: -1)
        #expect(other.update.remove == ["milk"])
    }

    @Test func takingItDownToZeroMeansAllGone() {
        let r = review([found(bread)])
        r.step("bread", by: -1)
        #expect(r.update.remove == ["bread"])
        #expect(r.update.amounts.isEmpty)
    }

    @Test func somethingNotSpottedStaysUnlessMarkedGone() {
        let r = review([found(egg)])
        #expect(r.update.remove.isEmpty)
        r.toggleGone("rice")
        #expect(r.update.remove == ["rice"])
        r.toggleGone("rice")
        #expect(r.update.isEmpty)
    }

    @Test func aFirstScanWithAnEmptyPantryWorksAsBefore() {
        let r = ScanReview(result: ScanResult(items: [found(egg, count: 4), found(milk, .maybe)], usedModel: true))
        #expect(!r.isUpdate)
        #expect(r.looksRight == [egg])
        #expect(r.maybe == [milk])
        #expect(r.selected == [egg])
    }

    @Test func newThingsGetACountToo() {
        let r = review([found(onion, count: 3), found(egg)])
        #expect(r.amount(for: "onion") == 3)
        #expect(r.isGuess("onion"))
        #expect(r.update.addAmounts == ["onion": 3])
        // Down past one goes back to "some", since it's being added either way.
        r.step("onion", by: -1)
        r.step("onion", by: -1)
        r.step("onion", by: -1)
        #expect(r.amount(for: "onion") == nil)
        #expect(r.update.addAmounts.isEmpty)
        #expect(r.update.add == [onion])
        r.step("onion", by: 1)
        #expect(r.update.addAmounts == ["onion": 1])
    }

    @Test func aNewThingLeftOutTakesItsCountWithIt() {
        let r = review([found(onion, count: 3)])
        r.toggle(onion)
        #expect(r.update.isEmpty)
    }

    @Test func aFirstScanKeepsItsCounts() throws {
        let db = try TestDatabase()
        let r = ScanReview(result: ScanResult(items: [found(egg, count: 6), found(milk)], usedModel: true))
        PantryRepository.replace(with: r.selected, in: db.context)
        PantryRepository.apply(PantryUpdate(addAmounts: r.update.addAmounts), in: db.context)
        let saved = Dictionary(uniqueKeysWithValues: PantryRepository.all(in: db.context).map { ($0.ingredientID, $0) })
        #expect(saved["egg"]?.quantity == 6)
        #expect(saved["milk"]?.quantity == nil)
    }

    @Test func applyingAddsSetsAndRemoves() throws {
        let db = try TestDatabase()
        PantryRepository.replace(with: [egg, milk, bread], in: db.context)
        PantryRepository.setAmount(6, unit: .items, for: "egg", in: db.context)
        let update = PantryUpdate(add: [onion, egg], amounts: ["egg": 2, "milk": 1], remove: ["bread"],
                                  addAmounts: ["onion": 4])
        let removed = PantryRepository.apply(update, in: db.context)
        let saved = Dictionary(uniqueKeysWithValues: PantryRepository.all(in: db.context).map { ($0.ingredientID, $0) })
        #expect(Set(saved.keys) == ["egg", "milk", "onion"])
        #expect(saved["egg"]?.quantity == 2)
        #expect(saved["milk"]?.quantity == 1)
        #expect(saved["milk"]?.unit == PantryUnit.items.rawValue)
        #expect(saved["onion"]?.quantity == 4)
        #expect(removed == [bread])
    }

    @Test func whatRanOutGoesOnTheShoppingList() throws {
        let db = try TestDatabase()
        PantryRepository.replace(with: [bread], in: db.context)
        let removed = PantryRepository.apply(PantryUpdate(remove: ["bread"]), in: db.context)
        ShoppingRepository.addRunOut(removed, enabled: true, in: db.context)
        #expect(ShoppingRepository.all(in: db.context).map(\.ingredientID) == ["bread"])
    }
}
