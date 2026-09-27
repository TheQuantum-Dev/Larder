//
//  TryItModelTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/20/26.
//

import CoreGraphics
import Testing
@testable import Larder

@MainActor
struct TryItModelTests {
    private let egg = IngredientCatalog.resolve("egg")!

    private func tinyImage() -> CGImage {
        let context = CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return context.makeImage()!
    }

    private func model(finding items: [DetectedItem] = [], minimumPeek: Duration = .zero) -> TryItModel {
        TryItModel(minimumPeek: minimumPeek) { _ in ScanResult(items: items, usedModel: true) }
    }

    @Test func aFastScanStillShowsThePeekForTheMinimumTime() async {
        let m = model(minimumPeek: .milliseconds(300))
        let clock = ContinuousClock()
        let start = clock.now
        m.begin(with: tinyImage())
        await m.waitForScan()
        #expect(clock.now - start >= .milliseconds(300))
        #expect(m.phaseID == 2)
    }

    @Test func startsOnThePrompt() {
        #expect(model().phaseID == 0)
    }

    @Test func aPhotoMovesToScanningThenReview() async {
        let found = DetectedItem(item: egg, tier: .looksRight, votes: 3, runs: 3, hasVisionSupport: false)
        let m = model(finding: [found])
        m.begin(with: tinyImage())
        #expect(m.phaseID == 1)
        await m.waitForScan()
        #expect(m.phaseID == 2)
        #expect(m.review?.selected == [egg])
        #expect(m.review?.isManual == false)
    }

    @Test func skippingThePhotoGoesStraightToAManualReview() {
        let m = model()
        m.startByHand()
        #expect(m.phaseID == 2)
        #expect(m.review?.isManual == true)
    }

    @Test func anUnusablePhotoReturnsToThePromptWithANote() {
        let m = model()
        m.photoUnusable()
        #expect(m.phaseID == 0)
        #expect(m.problem != nil)
    }

    @Test func aNewPhotoClearsTheNote() async {
        let m = model()
        m.photoUnusable()
        m.begin(with: tinyImage())
        #expect(m.problem == nil)
        await m.waitForScan()
    }

    @Test func severalPhotosEndInOneReview() async {
        let milk = IngredientCatalog.resolve("milk")!
        var next = 0
        let m = TryItModel(minimumPeek: .zero) { _ in
            next += 1
            return ScanResult(items: [DetectedItem(item: next == 1 ? egg : milk, tier: .looksRight, votes: 3,
                                                   runs: 3, hasVisionSupport: false)], usedModel: true)
        }
        m.add(tinyImage())
        m.add(tinyImage())
        #expect(m.phaseID == 0)
        m.finishPhotos()
        #expect(m.phaseID == 1)
        await m.waitForScan()
        #expect(Set(m.review?.selected ?? []) == [egg, milk])
    }

    @Test func anUpdateReviewKnowsWhatsInThePantry() async {
        let m = model(finding: [DetectedItem(item: egg, tier: .looksRight, votes: 3, runs: 3, hasVisionSupport: false)])
        m.pantry = [PantrySnapshot(item: egg, quantity: 6, unit: .items)]
        m.begin(with: tinyImage())
        await m.waitForScan()
        #expect(m.review?.alreadyHave.map(\.id) == ["egg"])
        #expect(m.review?.looksRight.isEmpty == true)
    }

    @Test func aBarcodeJoinsTheReviewThatsOpen() {
        let rice = IngredientCatalog.resolve("rice")!
        let m = model()
        m.startByHand()
        m.review?.add(egg)
        m.foundByBarcode([rice])
        #expect(m.review?.selected == [egg, rice])
    }

    @Test func startingOverReturnsToThePrompt() async {
        let m = model()
        m.begin(with: tinyImage())
        await m.waitForScan()
        m.startOver()
        #expect(m.phaseID == 0)
    }
}
