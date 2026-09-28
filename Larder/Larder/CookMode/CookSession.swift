//
//  CookSession.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation
import Observation

/// One go at cooking a recipe: where you are in it, which things you've
/// gathered, and every step's timer. Timers keep running when you move on to
/// the next step, so a pot can simmer while you chop.
@Observable
final class CookSession {
    enum Phase: Hashable {
        case gather
        case step(Int)
        case done
        /// The meal has been marked as made.
        case made
    }

    let recipe: Recipe
    private(set) var phase: Phase
    private(set) var timers: [Int: StepTimer] = [:]
    /// Goes up each time a timer runs out, which is what triggers the haptic.
    private(set) var finishedCount = 0
    /// Steps whose timer ran out while you were looking and is still ringing.
    /// One that ran out while Larder was in the background has already rung
    /// through its notification, so it doesn't start again on return.
    private(set) var ringing: Set<Int> = []
    /// Goes up each time a timer is started, so Cook Mode can offer to send
    /// a notification the first time.
    private(set) var timersStarted = 0
    /// True when notifications are turned off, so timers can only ring while
    /// Larder is open.
    var notificationsOff = false

    var checkedEquipment: Set<Equipment> = []
    var checkedIngredients: Set<Int> = []

    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var alarms: [Int: Task<Void, Never>] = [:]
    /// Where timer notifications go. Nil sends none, which is what tests want.
    @ObservationIgnored var notifier: TimerNotifying?
    /// Whether Larder is on screen, so a timer running out can ring.
    @ObservationIgnored var appIsActive = true

    /// `clock` is a parameter so tests can move time forward by hand.
    init(recipe: Recipe, phase: Phase = .gather, clock: @escaping () -> Date = { Date() }) {
        self.recipe = recipe
        self.phase = phase
        self.clock = clock
        for (index, step) in recipe.steps.enumerated() {
            if let seconds = step.timer {
                timers[index] = StepTimer(duration: TimeInterval(seconds))
            }
        }
    }

    // MARK: - Where you are

    var stepCount: Int { recipe.steps.count }

    var currentStep: Int? {
        if case .step(let index) = phase { return index }
        return nil
    }

    /// 0 while gathering, then how far through the steps, and 1 when done.
    var progress: Double {
        switch phase {
        case .gather: 0
        case .step(let index): Double(index + 1) / Double(max(stepCount, 1))
        case .done, .made: 1
        }
    }

    func begin() {
        phase = stepCount > 0 ? .step(0) : .done
    }

    func next() {
        guard case .step(let index) = phase else { return }
        phase = index + 1 < stepCount ? .step(index + 1) : .done
    }

    func back() {
        switch phase {
        case .gather: break
        case .step(let index): phase = index == 0 ? .gather : .step(index - 1)
        case .done: phase = stepCount > 0 ? .step(stepCount - 1) : .gather
        case .made: break   // it's been recorded, so there's no going back
        }
    }

    /// Marks the meal as made. Only possible from the done screen.
    func finish() {
        if phase == .done { phase = .made }
    }

    func jump(to step: Int) {
        guard (0..<stepCount).contains(step) else { return }
        phase = .step(step)
    }

    // MARK: - Timers

    func startTimer(_ step: Int) {
        change(step) { $0.start(now: clock()) }
        scheduleAlarm(for: step)
        timersStarted += 1
    }

    /// Sends the notifications again for every running timer, for right
    /// after someone allows them.
    func rescheduleNotifications() {
        for (step, timer) in timers where timer.isRunning {
            notifier?.schedule(TimerReminder.make(recipe: recipe, step: step, seconds: timer.remaining(at: clock())))
        }
    }

    func pauseTimer(_ step: Int) {
        change(step) { $0.pause(now: clock()) }
        cancelAlarm(for: step)
    }

    func resumeTimer(_ step: Int) {
        change(step) { $0.resume(now: clock()) }
        scheduleAlarm(for: step)
    }

    func resetTimer(_ step: Int) {
        change(step) { $0.reset() }
        cancelAlarm(for: step)
        stopRinging(step)
    }

    /// Stop on a ringing timer. It stays at "Time's up!" until it's reset.
    func stopRinging(_ step: Int) {
        ringing.remove(step)
        notifier?.clearDelivered(id: TimerReminder.id(recipeID: recipe.id, step: step))
    }

    func stopAllRinging() {
        for step in ringing { stopRinging(step) }
    }

    /// Timers on steps other than the one on screen that are running or have
    /// just gone off, for the strip along the top.
    var otherActiveTimers: [(step: Int, timer: StepTimer)] {
        timers
            .filter { $0.key != currentStep && ($0.value.isRunning || $0.value.isFinished) }
            .sorted { $0.key < $1.key }
            .map { (step: $0.key, timer: $0.value) }
    }

    /// Checks every running timer against the clock. Called when an alarm
    /// fires and when the app comes back to the foreground, since a timer can
    /// run out while the app is asleep.
    ///
    /// `canRing` is false when coming back from the background: anything that
    /// ran out meanwhile already rang through its notification.
    func refresh(canRing: Bool? = nil) {
        let rings = canRing ?? appIsActive
        for (step, timer) in timers {
            var updated = timer
            if updated.finishIfDue(now: clock()) {
                timers[step] = updated
                finishedCount += 1
                if rings { ringing.insert(step) }
            }
        }
    }

    #if DEBUG
    /// Makes a step's timer ring straight away, for screenshots.
    func debugRing(_ step: Int) {
        guard let duration = timers[step]?.duration else { return }
        let past = clock().addingTimeInterval(-duration - 1)
        change(step) { $0.start(now: past) }
        refresh(canRing: true)
    }
    #endif

    /// Stops any pending alarms and notifications, for when Cook Mode closes.
    func stop() {
        for step in Array(alarms.keys) { cancelAlarm(for: step) }
        stopAllRinging()
    }

    // MARK: - Private

    private func change(_ step: Int, _ update: (inout StepTimer) -> Void) {
        guard var timer = timers[step] else { return }
        update(&timer)
        timers[step] = timer
    }

    private func cancelAlarm(for step: Int) {
        alarms[step]?.cancel()
        alarms[step] = nil
        notifier?.cancel(id: TimerReminder.id(recipeID: recipe.id, step: step))
    }

    private func scheduleAlarm(for step: Int) {
        alarms[step]?.cancel()
        guard let timer = timers[step] else { return }
        let seconds = timer.remaining(at: clock())
        notifier?.schedule(TimerReminder.make(recipe: recipe, step: step, seconds: seconds))
        alarms[step] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}
