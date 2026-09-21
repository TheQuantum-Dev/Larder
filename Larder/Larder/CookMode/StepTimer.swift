//
//  StepTimer.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

/// A cooking timer for one recipe step.
///
/// It stores *when it will end*, not how much is left, so it stays right even
/// if the app is in the background or the screen sleeps: the time remaining is
/// always worked out from the current time. Every function that depends on the
/// time takes `now` as a parameter, which is what lets the tests run instantly.
nonisolated struct StepTimer: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case idle
        case running(end: Date)
        case paused(remaining: TimeInterval)
        case finished
    }

    let duration: TimeInterval
    private(set) var state: State = .idle

    init(duration: TimeInterval) {
        self.duration = duration
    }

    var isIdle: Bool { state == .idle }
    var isFinished: Bool { state == .finished }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    mutating func start(now: Date) {
        state = .running(end: now.addingTimeInterval(duration))
    }

    mutating func pause(now: Date) {
        guard case .running(let end) = state else { return }
        state = .paused(remaining: max(0, end.timeIntervalSince(now)))
    }

    mutating func resume(now: Date) {
        guard case .paused(let remaining) = state else { return }
        state = .running(end: now.addingTimeInterval(remaining))
    }

    mutating func reset() {
        state = .idle
    }

    /// Moves a running timer to finished if its time is up. Returns true only
    /// for the moment it changes, so a caller can react exactly once.
    @discardableResult
    mutating func finishIfDue(now: Date) -> Bool {
        guard case .running(let end) = state, end <= now else { return false }
        state = .finished
        return true
    }

    func remaining(at now: Date) -> TimeInterval {
        switch state {
        case .idle: duration
        case .running(let end): max(0, end.timeIntervalSince(now))
        case .paused(let remaining): remaining
        case .finished: 0
        }
    }

    /// How much of the time has gone, from 0 to 1.
    func progress(at now: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining(at: now) / duration))
    }
}

nonisolated enum ClockText {
    /// 245 seconds becomes "4:05"; 9 becomes "0:09".
    static func text(seconds: Int) -> String {
        let safe = max(0, seconds)
        return "\(safe / 60):" + String(format: "%02d", safe % 60)
    }
}
