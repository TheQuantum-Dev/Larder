//
//  StreakWeekTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation
import Testing
@testable import Larder

struct StreakWeekTests {
    /// Los Angeles, because it has daylight saving time. 1 = a Sunday-first week, 2 = Monday-first.
    private func calendar(firstWeekday: Int = 2) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    /// September 2026: the 25th is a Friday.
    private func at(_ day: Int, _ hour: Int = 12, _ minute: Int = 0, month: Int = 9) -> Date {
        calendar().date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func week(_ cooked: [Date], now: Date, firstWeekday: Int = 2) -> StreakWeek {
        StreakWeek.make(cookedDates: cooked, now: now, calendar: calendar(firstWeekday: firstWeekday))
    }

    private func dayNumbers(_ week: StreakWeek, firstWeekday: Int = 2) -> [Int] {
        week.days.map { calendar(firstWeekday: firstWeekday).component(.day, from: $0.date) }
    }

    // MARK: - The week itself

    @Test func aMondayWeekRunsMondayToSunday() {
        let w = week([], now: at(25))
        #expect(dayNumbers(w) == [21, 22, 23, 24, 25, 26, 27])
        #expect(w.days.map { calendar().component(.weekday, from: $0.date) } == [2, 3, 4, 5, 6, 7, 1])
    }

    @Test func aSundayWeekRunsSundayToSaturday() {
        let w = week([], now: at(25), firstWeekday: 1)
        #expect(dayNumbers(w, firstWeekday: 1) == [20, 21, 22, 23, 24, 25, 26])
        #expect(w.days.map { calendar().component(.weekday, from: $0.date) } == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test func statesFollowTheCookingAndTheClock() {
        let w = week([at(21), at(22), at(24)], now: at(25, 10))
        #expect(w.days.map(\.state) == [.cooked, .cooked, .missed, .cooked, .today, .upcoming, .upcoming])
        #expect(w.days.map(\.isToday) == [false, false, false, false, true, false, false])
        #expect(w.cookedCount == 3)
        #expect(!w.isPerfect)
    }

    @Test func todayFillsInOnceThereIsAMeal() {
        let w = week([at(25, 9)], now: at(25, 18))
        #expect(w.days[4].state == .cooked)
        #expect(w.days[4].isToday)
    }

    @Test func manyMealsInADayCountOnce() {
        #expect(week([at(21, 8), at(21, 12), at(21, 19)], now: at(25)).cookedCount == 1)
    }

    @Test func aMealLateInTheDayBelongsToThatDay() {
        let w = week([at(24, 23, 59)], now: at(25, 7))
        #expect(w.days[3].state == .cooked)
        #expect(w.days[4].state == .today)
    }

    @Test func lastWeeksMealsDoNotShowUp() {
        // Sunday the 20th is the end of the previous week when weeks start on Monday...
        #expect(week([at(20)], now: at(25)).cookedCount == 0)
        // ...but the start of this one when they start on Sunday.
        #expect(week([at(20)], now: at(25), firstWeekday: 1).cookedCount == 1)
    }

    @Test func aPerfectWeekHasAllSevenFilled() {
        let w = week((21...27).map { at($0) }, now: at(27, 20))
        #expect(w.isPerfect)
        #expect(w.cookedCount == 7)
        #expect(w.days.allSatisfy { $0.state == .cooked })
    }

    @Test func aNewWeekStartsEmptyEvenMidStreak() {
        // Cooked Sunday night; it's just past midnight on Monday.
        let w = week([at(27, 23, 59)], now: at(28, 0, 5))
        #expect(dayNumbers(w) == [28, 29, 30, 1, 2, 3, 4])
        #expect(w.cookedCount == 0)
        #expect(w.days[0].state == .today)
    }

    @Test func daylightSavingDoesNotBreakTheWeek() {
        // Clocks jumped forward on Sunday March 8th 2026.
        let sundayFirst = week([], now: at(10, 12, month: 3), firstWeekday: 1)
        #expect(dayNumbers(sundayFirst, firstWeekday: 1) == [8, 9, 10, 11, 12, 13, 14])
        let mondayFirst = week([], now: at(6, 12, month: 3))
        #expect(dayNumbers(mondayFirst) == [2, 3, 4, 5, 6, 7, 8])
        #expect(Set(mondayFirst.days.map(\.id)).count == 7)
    }

    // MARK: - Milestones

    @Test func milestonesAreFoundInOrder() {
        #expect(StreakMilestone.next(after: 0) == 3)
        #expect(StreakMilestone.next(after: 2) == 3)
        #expect(StreakMilestone.next(after: 3) == 7)
        #expect(StreakMilestone.next(after: 7) == 14)
        #expect(StreakMilestone.next(after: 99) == 100)
        #expect(StreakMilestone.next(after: 100) == nil)
        #expect(StreakMilestone.isMilestone(7))
        #expect(!StreakMilestone.isMilestone(8))
    }

    @Test func theLinePointsAtTheNextMilestone() {
        #expect(StreakMilestone.line(days: 4, coralEarned: true) == "3 more days to a 7-day streak")
        #expect(StreakMilestone.line(days: 6, coralEarned: true) == "1 more day to a 7-day streak")
        #expect(StreakMilestone.line(days: 100, coralEarned: true) == nil)
    }

    @Test func theFirstMilestoneMentionsCoralUntilItIsEarned() {
        #expect(StreakMilestone.line(days: 1, coralEarned: false) == "2 more days to unlock Coral Nutmeg")
        #expect(StreakMilestone.line(days: 1, coralEarned: true) == "2 more days to a 3-day streak")
    }

    // MARK: - What one more meal does

    private func progress(cooking day: Int, hour: Int = 12, after previous: [Date]) -> StreakProgress {
        StreakProgress.after(cookingAt: at(day, hour), previousDates: previous, calendar: calendar())
    }

    @Test func theFirstMealEverStartsAStreak() {
        let p = progress(cooking: 25, after: [])
        #expect(p.days == 1)
        #expect(p.isNewDay)
        #expect(p.milestone == nil)
        #expect(p.week.cookedCount == 1)
        #expect(!p.coralEarned)
    }

    @Test func aSecondMealTheSameDayIsNotANewDay() {
        let p = progress(cooking: 25, hour: 19, after: [at(25, 8)])
        #expect(!p.isNewDay)
        #expect(p.days == 1)
    }

    @Test func cookingOnKeepsTheStreakGoingAndHitsTheFirstMilestone() {
        let p = progress(cooking: 25, after: [at(23), at(24)])
        #expect(p.days == 3)
        #expect(p.isNewDay)
        #expect(p.milestone == 3)
        #expect(p.coralEarned)
    }

    @Test func aMilestoneOnlyCountsOnANewDay() {
        let p = progress(cooking: 25, hour: 19, after: [at(23), at(24), at(25, 8)])
        #expect(p.days == 3)
        #expect(!p.isNewDay)
        #expect(p.milestone == nil)
    }

    @Test func aGapStartsTheCountAgain() {
        let p = progress(cooking: 25, after: [at(20), at(21)])
        #expect(p.days == 1)
        #expect(p.milestone == nil)
    }

    @Test func fiveMealsEarnCoralEvenWithoutAStreak() {
        let p = progress(cooking: 25, after: [at(10), at(12), at(14), at(16)])
        #expect(p.days == 1)
        #expect(p.coralEarned)
    }
}
