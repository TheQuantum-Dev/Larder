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
    /// The shortest time the "peeking" screen stays up. On a fast phone Vision
    /// can finish in a blink, and a screen that flashes past looks like a glitch.
    private let minimumPeek: Duration
    private var scanTask: Task<Void, Never>?

    /// `scan` is a parameter so tests can hand in a fake instead of running
    /// Vision and the model, and `minimumPeek` so they don't have to wait.
    init(minimumPeek: Duration = .seconds(1.5),
         scan: @escaping (CGImage) async -> ScanResult = { await PantryScanner.scan($0) }) {
        self.minimumPeek = minimumPeek
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
        scanTask = Task { [minimumPeek] in
            // The scan and the minimum wait run side by side, so a slow scan
            // isn't made any slower and a fast one still gets its moment.
            async let pause: Void = { try? await Task.sleep(for: minimumPeek) }()
            let result = await scan(image)
            await pause
            guard !Task.isCancelled else { return }
            phase = .review(ScanReview(result: result))
        }
    }

    func startByHand() {
        scanTask?.cancel()
        problem = nil
        phase = .review(.manual())
    }

    /// Barcode results skip the scan entirely: a barcode already names the
    /// exact product, so there's nothing to run Vision or the model on.
    /// They still land on the same confirm screen, all pre-checked.
    func foundByBarcode(_ items: [ResolvedItem]) {
        scanTask?.cancel()
        problem = nil
        let review = ScanReview.manual()
        for item in items { review.add(item) }
        phase = .review(review)
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
