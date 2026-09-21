//
//  TryItModel.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import CoreGraphics
import Observation

/// Drives the try-it step: ask for a photo, scan it, then let the person
/// review the result. Skipping the photo goes straight to listing by hand.
@Observable
final class TryItModel {
    enum Phase {
        case prompt
        case scanning(CGImage)
        case review(ScanReview)
    }

    private(set) var phase: Phase = .prompt
    /// A gentle note on the prompt screen when the last photo couldn't be used.
    private(set) var problem: String?

    private let scan: (CGImage) async -> ScanResult
    private var scanTask: Task<Void, Never>?

    /// `scan` is a parameter so tests can hand in a fake instead of running
    /// Vision and the model.
    init(scan: @escaping (CGImage) async -> ScanResult = { await PantryScanner.scan($0) }) {
        self.scan = scan
    }

    /// A number per phase, handy for animating between them.
    var phaseID: Int {
        switch phase {
        case .prompt: 0
        case .scanning: 1
        case .review: 2
        }
    }

    var review: ScanReview? {
        if case .review(let review) = phase { return review }
        return nil
    }

    func begin(with image: CGImage) {
        scanTask?.cancel()
        problem = nil
        phase = .scanning(image)
        scanTask = Task {
            let result = await scan(image)
            guard !Task.isCancelled else { return }
            phase = .review(ScanReview(result: result))
        }
    }

    func startByHand() {
        scanTask?.cancel()
        problem = nil
        phase = .review(.manual())
    }

    func photoUnusable() {
        scanTask?.cancel()
        problem = "I couldn't open that photo. Want to try another?"
        phase = .prompt
    }

    func startOver() {
        scanTask?.cancel()
        problem = nil
        phase = .prompt
    }

    /// Stops any scan still running, for when the screen goes away.
    func cancel() {
        scanTask?.cancel()
    }

    /// Waits for the current scan to finish. Only tests need this.
    func waitForScan() async {
        await scanTask?.value
    }
}
