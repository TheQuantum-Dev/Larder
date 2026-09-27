//
//  ScanQueue.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import CoreGraphics
import Observation

/// Photos waiting to be looked at, worked through one at a time in the order
/// they were taken. Each one starts the moment it's added, so by the time the
/// person taps Done most of the work is already finished.
///
/// One at a time on purpose: each photo already asks the on-device model three
/// times, and piling several photos on top of that just makes them all slower.
@Observable
final class ScanQueue {
    struct Shot: Identifiable {
        let id: Int
        let image: CGImage
        /// Nil until this photo has been looked at.
        var result: ScanResult?
    }

    private(set) var shots: [Shot] = []
    /// The most photos in one go. Past this the scan takes too long to be worth it.
    static let limit = 8

    private let scan: (CGImage) async -> ScanResult
    private var worker: Task<Void, Never>?

    /// `scan` is a parameter so tests can hand in a fake.
    init(scan: @escaping (CGImage) async -> ScanResult = { await PantryScanner.scan($0) }) {
        self.scan = scan
    }

    var isFull: Bool { shots.count >= Self.limit }
    var isDone: Bool { shots.allSatisfy { $0.result != nil } }
    var finishedCount: Int { shots.filter { $0.result != nil }.count }

    /// Everything found so far, all photos together.
    var combined: ScanResult { ScanAggregator.combine(shots.compactMap(\.result)) }

    func add(_ image: CGImage) {
        guard !isFull else { return }
        shots.append(Shot(id: shots.count, image: image))
        startIfNeeded()
    }

    /// Waits until every photo added so far has been looked at.
    func waitUntilDone() async {
        while let worker {
            await worker.value
        }
    }

    /// Stops and forgets everything, for when the person backs out.
    func cancel() {
        worker?.cancel()
        worker = nil
        shots = []
    }

    private func startIfNeeded() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            // Everything here is on the main actor except the scan itself, so
            // checking for the next photo and clearing `worker` can't race with `add`.
            while let self, !Task.isCancelled,
                  let index = self.shots.firstIndex(where: { $0.result == nil }) {
                let id = self.shots[index].id
                let result = await self.scan(self.shots[index].image)
                guard !Task.isCancelled, let current = self.shots.firstIndex(where: { $0.id == id }) else { break }
                self.shots[current].result = result
            }
            // A cancelled run was already let go by `cancel`, and a newer one may be running.
            if !Task.isCancelled { self?.worker = nil }
        }
    }
}
