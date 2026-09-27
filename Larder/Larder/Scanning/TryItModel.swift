//
//  TryItModel.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import CoreGraphics
import Observation

/// Drives a scan: take one or more photos (each one is looked at in the
/// background as soon as it's taken), wait on the "peeking" screen for any
/// still going, then let the person review the result. Skipping the photos
/// goes straight to listing by hand.
@Observable
final class TryItModel {
    enum Phase {
        case prompt
        case scanning
        case review(ScanReview)
    }

    private(set) var phase: Phase = .prompt
    /// A gentle note on the prompt screen when the last photo couldn't be used.
    private(set) var problem: String?
    /// The photos taken so far, and what's been found in them.
    let queue: ScanQueue
    /// What's already in the pantry, when updating it. Empty for a first scan.
    var pantry: [PantrySnapshot] = []

    /// The shortest time the "peeking" screen stays up. On a fast phone Vision
    /// can finish in a blink, and a screen that flashes past looks like a glitch.
    private let minimumPeek: Duration
    private var finishTask: Task<Void, Never>?

    /// `scan` is a parameter so tests can hand in a fake instead of running
    /// Vision and the model, and `minimumPeek` so they don't have to wait.
    init(minimumPeek: Duration = .seconds(1.5),
         scan: @escaping (CGImage) async -> ScanResult = { await PantryScanner.scan($0) }) {
        self.minimumPeek = minimumPeek
        queue = ScanQueue(scan: scan)
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

    /// Adds a photo; it starts being looked at straight away.
    func add(_ image: CGImage) {
        problem = nil
        queue.add(image)
    }

    /// The person is done taking photos: show the peeking screen until every
    /// photo has been looked at (and for at least a moment), then the review.
    func finishPhotos() {
        guard !queue.shots.isEmpty else { return }
        finishTask?.cancel()
        phase = .scanning
        finishTask = Task { [queue, minimumPeek] in
            // The wait and the minimum run side by side, so slow photos aren't
            // made any slower and fast ones still get their moment.
            async let pause: Void = { try? await Task.sleep(for: minimumPeek) }()
            await queue.waitUntilDone()
            await pause
            guard !Task.isCancelled else { return }
            phase = .review(ScanReview(result: queue.combined, pantry: pantry))
        }
    }

    /// One photo, looked at right away.
    func begin(with image: CGImage) {
        add(image)
        finishPhotos()
    }

    func startByHand() {
        cancel()
        problem = nil
        phase = .review(.manual(pantry: pantry))
    }

    /// Barcode results skip the scan entirely: a barcode already names the
    /// exact product, so there's nothing to run Vision or the model on. They
    /// join the review that's open, or start one, all pre-checked.
    func foundByBarcode(_ items: [ResolvedItem]) {
        if let review {
            for item in items { review.add(item) }
            return
        }
        cancel()
        problem = nil
        let review = ScanReview.manual(pantry: pantry)
        for item in items { review.add(item) }
        phase = .review(review)
    }

    func photoUnusable() {
        problem = "I couldn't open that photo. Want to try another?"
        if queue.shots.isEmpty { phase = .prompt }
    }

    func startOver() {
        cancel()
        problem = nil
        phase = .prompt
    }

    /// Stops any scan still running and forgets the photos, for when the screen goes away.
    func cancel() {
        finishTask?.cancel()
        queue.cancel()
    }

    /// Waits for the photos to finish and the review to open. Only tests need this.
    func waitForScan() async {
        await finishTask?.value
    }
}
