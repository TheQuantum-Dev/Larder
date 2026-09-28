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
    /// Steps whose timer has gone off and is still ringing, until Stop. With
    /// system alarms that's whatever the alarm says; otherwise it's a timer
    /// that ran out while you were looking (one that ran out in the background
    /// already rang through its notification).
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
    /// Wakes the session when a running timer is due, while the app is open.
    @ObservationIgnored private var wakeups: [Int: Task<Void, Never>] = [:]
    /// Where timer notifications go. Nil sends none, which is what tests want.
    @ObservationIgnored var notifier: TimerNotifying?
    /// System alarms (AlarmKit), used instead of notifications once allowed.
    @ObservationIgnored var systemAlarms: CookAlarming?
    /// Each step's system alarm, while it has one.
    @ObservationIgnored private(set) var alarmIDs: [Int: UUID] = [:]

    /// True when timers ring as real alarms: on a locked phone, on silent, with
    /// a countdown on the lock screen.
    var usesSystemAlarms: Bool { systemAlarms?.isAuthorized == true }
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

    /// Sets up alarms or notifications again for every running timer, for
    /// right after someone allows them.
    func rescheduleAlerts() {
        for (step, timer) in timers where timer.isRunning {
            scheduleAlarm(for: step)
        }
    }

    func pauseTimer(_ step: Int) {
        change(step) { $0.pause(now: clock()) }
        if let id = alarmIDs[step] {
            wakeups[step]?.cancel()
            systemAlarms?.pause(id: id)
        } else {
            cancelAlarm(for: step)
        }
    }

    func resumeTimer(_ step: Int) {
        change(step) { $0.resume(now: clock()) }
        if let id = alarmIDs[step] {
            systemAlarms?.resume(id: id)
            scheduleWakeup(for: step)
        } else {
            scheduleAlarm(for: step)
        }
    }

    func resetTimer(_ step: Int) {
        change(step) { $0.reset() }
        cancelAlarm(for: step)
        stopRinging(step)
    }

    /// Stop on a ringing timer. It stays at "Time's up!" until it's reset.
    func stopRinging(_ step: Int) {
        ringing.remove(step)
        if let id = alarmIDs.removeValue(forKey: step) { systemAlarms?.cancel(id: id) }
        notifier?.clearDelivered(id: TimerReminder.id(recipeID: recipe.id, step: step))
    }

    /// Keeps the session in step with the system alarms. One that's ringing
    /// shows as ringing here (and counts as done, even if the app was asleep);
    /// one that has vanished was stopped from the lock screen, so it stops
    /// ringing here too.
    func applyAlarmStates(_ states: [UUID: CookAlarmState]) {
        for (step, id) in alarmIDs {
            switch states[id] {
            case .ringing:
                if var timer = timers[step], !timer.isFinished {
                    let due = clock().addingTimeInterval(timer.remaining(at: clock()) + 1)
                    if timer.finishIfDue(now: due) {
                        timers[step] = timer
                        finishedCount += 1
                    }
                }
                ringing.insert(step)
            case nil:
                if ringing.contains(step) || timers[step]?.isFinished == true {
                    ringing.remove(step)
                    alarmIDs[step] = nil
                }
            default:
                break
            }
        }
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
        for step in Set(wakeups.keys).union(alarmIDs.keys) { cancelAlarm(for: step) }
        stopAllRinging()
    }

    #if DEBUG
    /// Swaps a step's timer for a short one, for trying alarms quickly.
    func debugShorten(_ step: Int, to seconds: TimeInterval) {
        guard timers[step] != nil else { return }
        timers[step] = StepTimer(duration: seconds)
    }
    #endif

    // MARK: - Private

    private func change(_ step: Int, _ update: (inout StepTimer) -> Void) {
        guard var timer = timers[step] else { return }
        update(&timer)
        timers[step] = timer
    }

    private func cancelAlarm(for step: Int) {
        wakeups[step]?.cancel()
        wakeups[step] = nil
        if let id = alarmIDs.removeValue(forKey: step) { systemAlarms?.cancel(id: id) }
        notifier?.cancel(id: TimerReminder.id(recipeID: recipe.id, step: step))
    }

    /// A system alarm when they're allowed, otherwise a notification, plus a
    /// wake-up for while the app is open.
    private func scheduleAlarm(for step: Int) {
        guard let timer = timers[step] else { return }
        let seconds = timer.remaining(at: clock())
        if usesSystemAlarms, let systemAlarms {
            if let old = alarmIDs[step] { systemAlarms.cancel(id: old) }
            let id = UUID()
            alarmIDs[step] = id
            systemAlarms.start(id: id, recipe: recipe, step: step, seconds: seconds)
            notifier?.cancel(id: TimerReminder.id(recipeID: recipe.id, step: step))
        } else {
            notifier?.schedule(TimerReminder.make(recipe: recipe, step: step, seconds: seconds))
        }
        scheduleWakeup(for: step)
    }

    private func scheduleWakeup(for step: Int) {
        wakeups[step]?.cancel()
        guard let timer = timers[step] else { return }
        let seconds = timer.remaining(at: clock())
        wakeups[step] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }
}
