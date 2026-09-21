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

    private func model(finding items: [DetectedItem] = []) -> TryItModel {
        TryItModel { _ in ScanResult(items: items, usedModel: true) }
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

    @Test func startingOverReturnsToThePrompt() async {
        let m = model()
        m.begin(with: tinyImage())
        await m.waitForScan()
        m.startOver()
        #expect(m.phaseID == 0)
    }
}
