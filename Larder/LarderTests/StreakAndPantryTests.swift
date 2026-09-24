//
//  StreakAndPantryTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/24/26.
//

import Foundation
import Testing
@testable import Larder

struct CookingStreakTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Thursday 24 September 2026, early afternoon.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 14))! }

    private func daysAgo(_ days: Int, hour: Int = 12) -> Date {
        let day = calendar.date(byAdding: .day, value: -days, to: now)!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    private func status(_ dates: [Date]) -> CookingStreak.Status {
        CookingStreak.status(from: dates, now: now, calendar: calendar)
    }

    @Test func noMealsMeansNoStreak() {
        #expect(status([]) == .none)
    }

    @Test func cookingTodayMakesItSafe() {
        #expect(status([daysAgo(0), daysAgo(1), daysAgo(2)]) == .safe(days: 3))
    }

    @Test func notCookingYetTodayOnlyPutsItAtRisk() {
        #expect(status([daysAgo(1), daysAgo(2)]) == .atRisk(days: 2))
    }

    @Test func missingYesterdayEndsIt() {
        #expect(status([daysAgo(2), daysAgo(3)]) == .none)
    }

    @Test func aGapBreaksTheRunEvenIfItWasLongBefore() {
        #expect(status([daysAgo(0), daysAgo(1), daysAgo(3), daysAgo(4), daysAgo(5)]) == .safe(days: 2))
    }

    @Test func twoMealsInOneDayCountOnce() {
        #expect(status([daysAgo(0, hour: 8), daysAgo(0, hour: 19)]) == .safe(days: 1))
    }

    @Test func bestIsTheLongestRunEver() {
        let dates = [daysAgo(10), daysAgo(9), daysAgo(8), daysAgo(7), daysAgo(1), daysAgo(0)]
        #expect(CookingStreak.best(from: dates, calendar: calendar) == 4)
        #expect(CookingStreak.best(from: [], calendar: calendar) == 0)
    }
}

struct StreakReminderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func at(day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    @Test func noStreakMeansNoReminder() {
        #expect(StreakReminder.plan(mealDates: [], now: at(day: 24, hour: 10), calendar: calendar) == nil)
    }

    @Test func anAtRiskStreakGetsAReminderThisEvening() {
        let plan = StreakReminder.plan(mealDates: [at(day: 23, hour: 12), at(day: 22, hour: 12)],
                                       now: at(day: 24, hour: 10), calendar: calendar)
        #expect(plan?.fireDate == at(day: 24, hour: StreakReminder.hour))
        #expect(plan?.title.contains("2-day streak") == true)
    }

    @Test func afterSevenTheresNoLastMinuteReminder() {
        let plan = StreakReminder.plan(mealDates: [at(day: 23, hour: 12)],
                                       now: at(day: 24, hour: 20), calendar: calendar)
        #expect(plan == nil)
    }

    @Test func cookingTodayMovesTheReminderToTomorrow() {
        let plan = StreakReminder.plan(mealDates: [at(day: 24, hour: 9), at(day: 23, hour: 12)],
                                       now: at(day: 24, hour: 10), calendar: calendar)
        #expect(plan?.fireDate == at(day: 25, hour: StreakReminder.hour))
        #expect(plan?.title.contains("Day 3") == true)
    }

    @Test func theCopyNeverScolds() {
        let plans = [
            StreakReminder.plan(mealDates: [at(day: 23, hour: 12)], now: at(day: 24, hour: 10), calendar: calendar),
            StreakReminder.plan(mealDates: [at(day: 24, hour: 9)], now: at(day: 24, hour: 10), calendar: calendar),
        ].compactMap { $0 }
        #expect(plans.count == 2)
        for plan in plans {
            let text = (plan.title + " " + plan.body).lowercased()
            #expect(!text.contains("lose"))
            #expect(!text.contains("don't"))
            #expect(!text.contains("fail"))
        }
    }
}

struct PantryAmountTests {
    @Test func noAmountMeansNoText() {
        #expect(PantryAmount.text(quantity: nil, unit: nil) == nil)
    }

    @Test func countsReadAsPlainNumbers() {
        #expect(PantryAmount.text(quantity: 6, unit: PantryUnit.items.rawValue) == "6")
        #expect(PantryAmount.text(quantity: 6, unit: nil) == "6")
    }

    @Test func metricUnitsKeepTheirSymbol() {
        #expect(PantryAmount.text(quantity: 500, unit: "g") == "500 g")
        #expect(PantryAmount.text(quantity: 1.5, unit: "L") == "1.5 L")
    }

    @Test func containersArePluralisedProperly() {
        #expect(PantryAmount.text(quantity: 1, unit: "cans") == "1 can")
        #expect(PantryAmount.text(quantity: 3, unit: "cans") == "3 cans")
    }

    @Test func steppingUsesTheUnitsOwnSizeAndStopsAtZero() {
        #expect(PantryAmount.stepped(500, by: 1, unit: .grams) == 550)
        #expect(PantryAmount.stepped(1, by: -1, unit: .kilograms) == 0.5)
        #expect(PantryAmount.stepped(0, by: -1, unit: .items) == 0)
    }
}

@MainActor
struct PantrySetAmountTests {
    @Test func settingAndClearingAnAmount() throws {
        let db = try TestDatabase()
        PantryRepository.replace(with: [IngredientCatalog.resolve("egg")!], in: db.context)

        PantryRepository.setAmount(6, unit: .items, for: "egg", in: db.context)
        #expect(PantryRepository.all(in: db.context).first?.amountText == "6")

        PantryRepository.setAmount(nil, unit: .items, for: "egg", in: db.context)
        let egg = PantryRepository.all(in: db.context).first
        #expect(egg?.quantity == nil)
        #expect(egg?.unit == nil)
    }

    @Test func itemsAreGroupedByCatalogCategory() throws {
        let db = try TestDatabase()
        PantryRepository.replace(with: [IngredientCatalog.resolve("egg")!, ResolvedItem(customName: "Kimchi")],
                                 in: db.context)
        let items = PantryRepository.all(in: db.context)
        #expect(items.first { $0.ingredientID == "egg" }?.category == .dairyAndEggs)
        #expect(items.first { $0.isCustom }?.category == nil)
    }
}
