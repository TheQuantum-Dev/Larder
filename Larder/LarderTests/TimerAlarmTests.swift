//
//  TimerAlarmTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/27/26.
//

import Foundation
import Testing
@testable import Larder

/// Keeps what a cook session would have sent to the notification center.
@MainActor
final class FakeNotifier: TimerNotifying {
    var scheduled: [String: TimerReminder] = [:]
    var cleared: [String] = []

    func schedule(_ reminder: TimerReminder) { scheduled[reminder.id] = reminder }
    func cancel(id: String) { scheduled[id] = nil }
    func clearDelivered(id: String) { cleared.append(id) }
}

/// A Cook Mode timer ringing until it's stopped, and the notification that
/// goes with it.
@MainActor
struct TimerAlarmTests {
    private func session() -> (CookSession, TestClock, FakeNotifier, Int) {
        let clock = TestClock()
        let recipe = RecipeStore.all.first { recipe in recipe.steps.contains { $0.timer != nil } }!
        let session = CookSession(recipe: recipe, clock: { clock.now })
        let notifier = FakeNotifier()
        session.notifier = notifier
        let step = recipe.steps.firstIndex { $0.timer != nil }!
        return (session, clock, notifier, step)
    }

    @Test func aTimerThatRunsOutWhileYouWatchKeepsRingingUntilStop() {
        let (s, clock, _, step) = session()
        s.startTimer(step)
        clock.advance(s.timers[step]!.duration)
        s.refresh()
        #expect(s.ringing == [step])
        // Checking again doesn't stop it: only Stop does.
        clock.advance(30)
        s.refresh()
        #expect(s.ringing == [step])
        s.stopRinging(step)
        #expect(s.ringing.isEmpty)
        #expect(s.timers[step]!.isFinished)
    }

    @Test func aTimerThatRanOutInTheBackgroundDoesNotRingAgain() {
        let (s, clock, _, step) = session()
        s.startTimer(step)
        s.appIsActive = false
        clock.advance(s.timers[step]!.duration + 5)
        s.refresh(canRing: false)
        #expect(s.timers[step]!.isFinished)
        #expect(s.ringing.isEmpty)
    }

    @Test func startingSchedulesTheNotificationAndPausingCancelsIt() {
        let (s, clock, notifier, step) = session()
        let id = TimerReminder.id(recipeID: s.recipe.id, step: step)
        s.startTimer(step)
        #expect(notifier.scheduled[id]?.seconds == s.timers[step]!.duration)
        clock.advance(10)
        s.pauseTimer(step)
        #expect(notifier.scheduled[id] == nil)
        s.resumeTimer(step)
        #expect(notifier.scheduled[id]?.seconds == s.timers[step]!.duration - 10)
        s.resetTimer(step)
        #expect(notifier.scheduled[id] == nil)
    }

    @Test func stoppingClearsTheDeliveredNotification() {
        let (s, clock, notifier, step) = session()
        s.startTimer(step)
        clock.advance(s.timers[step]!.duration)
        s.refresh()
        s.stopRinging(step)
        #expect(notifier.cleared == [TimerReminder.id(recipeID: s.recipe.id, step: step)])
    }

    @Test func resettingARingingTimerStopsIt() {
        let (s, clock, _, step) = session()
        s.startTimer(step)
        clock.advance(s.timers[step]!.duration)
        s.refresh()
        s.resetTimer(step)
        #expect(s.ringing.isEmpty)
        #expect(s.timers[step]!.isIdle)
    }

    @Test func closingCookModeCancelsEverything() {
        let (s, _, notifier, step) = session()
        s.startTimer(step)
        s.stop()
        #expect(notifier.scheduled.isEmpty)
    }

    @Test func theNotificationSaysWhichStepAndWhatItWas() {
        let (s, _, _, step) = session()
        let reminder = TimerReminder.make(recipe: s.recipe, step: step, seconds: 90)
        #expect(reminder.title == "Step \(step + 1) is done")
        #expect(reminder.body.hasPrefix(s.recipe.title + ": "))
        #expect(reminder.seconds == 90)
    }

    @Test func longStepsAreCutAtAWord() {
        let long = "Simmer the sauce gently with the lid half on while you stir now and then so nothing catches on the bottom of the pan. Then serve."
        let snippet = TimerReminder.snippet(of: long, limit: 40)
        #expect(snippet.hasSuffix("…"))
        #expect(snippet.count <= 41)
        #expect(TimerReminder.snippet(of: "Boil the pasta. Drain it.") == "Boil the pasta.")
    }
}
