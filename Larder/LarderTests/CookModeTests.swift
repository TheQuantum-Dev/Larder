//
//  CookModeTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation
import Testing
@testable import Larder

/// A clock the tests can wind forward by hand.
@MainActor
final class TestClock {
    var now = Date(timeIntervalSince1970: 1_000_000)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

struct StepTimerTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test func startsIdleWithTheFullTimeLeft() {
        let timer = StepTimer(duration: 300)
        #expect(timer.isIdle)
        #expect(timer.remaining(at: start) == 300)
        #expect(timer.progress(at: start) == 0)
    }

    @Test func runningCountsDownFromTheClock() {
        var timer = StepTimer(duration: 300)
        timer.start(now: start)
        #expect(timer.isRunning)
        #expect(timer.remaining(at: start.addingTimeInterval(100)) == 200)
        #expect(timer.progress(at: start.addingTimeInterval(150)) == 0.5)
    }

    @Test func pausingHoldsTheTimeAndResumingContinues() {
        var timer = StepTimer(duration: 300)
        timer.start(now: start)
        timer.pause(now: start.addingTimeInterval(100))
        #expect(timer.isPaused)
        // Time passing while paused doesn't count.
        #expect(timer.remaining(at: start.addingTimeInterval(500)) == 200)
        timer.resume(now: start.addingTimeInterval(500))
        #expect(timer.remaining(at: start.addingTimeInterval(560)) == 140)
    }

    @Test func aTimerFinishesExactlyOnce() {
        var timer = StepTimer(duration: 60)
        timer.start(now: start)
        #expect(timer.finishIfDue(now: start.addingTimeInterval(59)) == false)
        #expect(timer.finishIfDue(now: start.addingTimeInterval(60)) == true)
        #expect(timer.isFinished)
        #expect(timer.finishIfDue(now: start.addingTimeInterval(120)) == false)
        #expect(timer.remaining(at: start.addingTimeInterval(120)) == 0)
    }

    @Test func resettingReturnsToTheStart() {
        var timer = StepTimer(duration: 60)
        timer.start(now: start)
        timer.reset()
        #expect(timer.isIdle)
        #expect(timer.remaining(at: start) == 60)
    }

    @Test func remainingNeverGoesNegative() {
        var timer = StepTimer(duration: 10)
        timer.start(now: start)
        #expect(timer.remaining(at: start.addingTimeInterval(1_000)) == 0)
    }

    @Test func clockTextShowsMinutesAndSeconds() {
        #expect(ClockText.text(seconds: 245) == "4:05")
        #expect(ClockText.text(seconds: 9) == "0:09")
        #expect(ClockText.text(seconds: 1500) == "25:00")
        #expect(ClockText.text(seconds: -5) == "0:00")
    }
}

@MainActor
struct CookSessionTests {
    private func session(_ recipeID: String = "egg-fried-rice") -> (CookSession, TestClock) {
        let clock = TestClock()
        let recipe = RecipeStore.recipe(withID: recipeID)!
        return (CookSession(recipe: recipe, clock: { clock.now }), clock)
    }

    // MARK: - Moving through the recipe

    @Test func startsByGatheringThenBeginsAtTheFirstStep() {
        let (s, _) = session()
        #expect(s.phase == .gather)
        #expect(s.progress == 0)
        s.begin()
        #expect(s.phase == .step(0))
    }

    @Test func nextWalksThroughEveryStepAndEndsDone() {
        let (s, _) = session()
        s.begin()
        for index in 1..<s.stepCount { s.next(); #expect(s.phase == .step(index)) }
        s.next()
        #expect(s.phase == .done)
        #expect(s.progress == 1)
    }

    @Test func backRetracesAndStopsAtGathering() {
        let (s, _) = session()
        s.begin()
        s.next()
        s.back()
        #expect(s.phase == .step(0))
        s.back()
        #expect(s.phase == .gather)
        s.back()
        #expect(s.phase == .gather)
    }

    @Test func backFromDoneReturnsToTheLastStep() {
        let (s, _) = session()
        s.begin()
        for _ in 0..<s.stepCount { s.next() }
        s.back()
        #expect(s.phase == .step(s.stepCount - 1))
    }

    @Test func jumpingIgnoresStepsThatDoNotExist() {
        let (s, _) = session()
        s.jump(to: 2)
        #expect(s.phase == .step(2))
        s.jump(to: 99)
        #expect(s.phase == .step(2))
    }

    // MARK: - Timers

    @Test func onlyStepsWithATimeGetATimer() {
        let (s, _) = session("pb-banana-toast")
        // The middle step (spread the peanut butter) has no timer.
        #expect(s.timers[0] != nil)
        #expect(s.timers[1] == nil)
    }

    @Test func aRunningTimerFinishesWhenTheClockPassesItsEnd() {
        let (s, clock) = session()
        let step = 1   // "Heat the oil..." has a 180 s timer
        s.startTimer(step)
        clock.advance(100)
        s.refresh()
        #expect(s.timers[step]?.isRunning == true)
        #expect(s.finishedCount == 0)

        clock.advance(100)
        s.refresh()
        #expect(s.timers[step]?.isFinished == true)
        #expect(s.finishedCount == 1)
        s.stop()
    }

    @Test func refreshOnlyCountsEachFinishOnce() {
        let (s, clock) = session()
        s.startTimer(1)
        clock.advance(500)
        s.refresh()
        s.refresh()
        #expect(s.finishedCount == 1)
        s.stop()
    }

    @Test func timersKeepRunningWhenYouMoveToTheNextStep() {
        let (s, clock) = session()
        s.jump(to: 1)
        s.startTimer(1)
        s.next()
        clock.advance(30)
        #expect(s.timers[1]?.isRunning == true)
        #expect(s.otherActiveTimers.map(\.step) == [1])
        s.stop()
    }

    @Test func theCurrentStepIsNotListedAmongTheOtherTimers() {
        let (s, _) = session()
        s.jump(to: 1)
        s.startTimer(1)
        #expect(s.otherActiveTimers.isEmpty)
        s.stop()
    }

    @Test func pausingThenResumingKeepsTheRemainingTime() {
        let (s, clock) = session()
        s.startTimer(1)
        clock.advance(60)
        s.pauseTimer(1)
        clock.advance(1_000)
        s.resumeTimer(1)
        #expect(s.timers[1]?.remaining(at: clock.now) == 120)
        s.stop()
    }

    @Test func resettingClearsAFinishedTimer() {
        let (s, clock) = session()
        s.startTimer(1)
        clock.advance(500)
        s.refresh()
        s.resetTimer(1)
        #expect(s.timers[1]?.isIdle == true)
        #expect(s.otherActiveTimers.isEmpty)
    }
}
