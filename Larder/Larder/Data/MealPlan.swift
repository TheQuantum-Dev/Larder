//
//  MealPlan.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation

/// Breakfast, lunch or dinner.
nonisolated enum MealSlot: String, CaseIterable, Sendable {
    case breakfast, lunch, dinner

    /// The meal after this one on the same day; nothing comes after dinner.
    var following: MealSlot? {
        switch self {
        case .breakfast: .lunch
        case .lunch: .dinner
        case .dinner: nil
        }
    }

    /// How many meals of the day are still to come, counting this one.
    var mealsLeft: Int {
        switch self {
        case .breakfast: 3
        case .lunch: 2
        case .dinner: 1
        }
    }

    var symbol: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        }
    }
}

/// The meal that's up next: which one, and which day's.
nonisolated struct NextMeal: Equatable, Sendable {
    let slot: MealSlot
    /// The meal-day it belongs to (see `MealPlan.mealDay`).
    let day: Date
    /// True when dinner is done and this is the breakfast to come tomorrow.
    let isTomorrow: Bool

    var title: String {
        switch slot {
        case .breakfast: isTomorrow ? "Tomorrow's breakfast" : "Breakfast pick"
        case .lunch: "Lunch pick"
        case .dinner: "Tonight's pick"
        }
    }

    /// A line from Nutmeg for the moment when the day's meals are all done.
    var note: String? {
        isTomorrow ? "Dinner's done! Here's an idea for tomorrow morning." : nil
    }

    /// How many meals of that day are still to come, counting this one.
    var mealsLeft: Int { slot.mealsLeft }
}

/// Works out which meal to suggest right now. The clock decides the meal
/// (breakfast in the morning, lunch around midday, dinner from late afternoon),
/// and a meal that's already been cooked moves the suggestion on to the next
/// one, ending with tomorrow's breakfast once dinner is done.
///
/// A day's meals run from 4am to 4am, so a snack cooked at 1am still counts
/// as the end of the night before and doesn't use up the next morning's breakfast.
nonisolated enum MealPlan {
    static let dayStartHour = 4
    static let lunchStartHour = 11
    static let dinnerStartHour = 16

    /// The meal a moment falls in: breakfast from 4:00, lunch from 11:00,
    /// dinner from 16:00 until 4:00 the next morning.
    static func slot(at date: Date, calendar: Calendar = .current) -> MealSlot {
        switch calendar.component(.hour, from: date) {
        case dayStartHour..<lunchStartHour: .breakfast
        case lunchStartHour..<dinnerStartHour: .lunch
        default: .dinner
        }
    }

    /// Midnight of the day this moment's meals belong to. Before 4am that's still yesterday.
    static func mealDay(of date: Date, calendar: Calendar = .current) -> Date {
        let midnight = calendar.startOfDay(for: date)
        guard calendar.component(.hour, from: date) < dayStartHour else { return midnight }
        return calendar.date(byAdding: .day, value: -1, to: midnight) ?? midnight
    }

    /// The meal to suggest at `now`, given when meals were cooked.
    static func next(now: Date, cookedDates: [Date], calendar: Calendar = .current) -> NextMeal {
        let day = mealDay(of: now, calendar: calendar)
        let done = Set(cookedDates
            .filter { mealDay(of: $0, calendar: calendar) == day }
            .map { slot(at: $0, calendar: calendar) })

        var current = slot(at: now, calendar: calendar)
        while done.contains(current) {
            guard let following = current.following else {
                return tomorrowsBreakfast(after: day, now: now, calendar: calendar)
            }
            current = following
        }
        return NextMeal(slot: current, day: day, isTomorrow: false)
    }

    private static func tomorrowsBreakfast(after day: Date, now: Date, calendar: Calendar) -> NextMeal {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) ?? day
        let start = calendar.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        // Past midnight the breakfast to come is on today's date, so it isn't "tomorrow's" any more.
        return NextMeal(slot: .breakfast, day: tomorrow, isTomorrow: !calendar.isDate(start, inSameDayAs: now))
    }

    /// The next moment the suggested meal can change by itself, for waking up Home on time.
    static func nextBoundary(after date: Date, calendar: Calendar = .current) -> Date {
        [dayStartHour, lunchStartHour, dinnerStartHour]
            .compactMap { hour in
                calendar.nextDate(after: date, matching: DateComponents(hour: hour, minute: 0, second: 0),
                                  matchingPolicy: .nextTime)
            }
            .min() ?? date.addingTimeInterval(3_600)
    }

    // MARK: - What's already been eaten

    /// The recipes cooked during the meal-day that `now` belongs to.
    static func cookedIDs(_ cooked: [(id: String, date: Date)], onMealDayOf now: Date,
                          calendar: Calendar = .current) -> Set<String> {
        let day = mealDay(of: now, calendar: calendar)
        return Set(cooked.filter { mealDay(of: $0.date, calendar: calendar) == day }.map(\.id))
    }

    /// Calories and macros logged on a meal-day.
    static func eaten(_ meals: [(date: Date, macros: Macros)], onMealDay day: Date,
                      calendar: Calendar = .current) -> Macros {
        meals
            .filter { mealDay(of: $0.date, calendar: calendar) == day }
            .reduce(Macros.zero) { $0 + $1.macros }
    }

    /// What one meal should come to for the meal that's up next: what's left of
    /// today's target, shared out over the meals still to come. After a big
    /// lunch, dinner aims lighter; after a light one, heavier. It stays within a
    /// reasonable band around the usual third of the day, so one odd day never
    /// swings the suggestions wildly. Without a goal there's nothing to adjust.
    static func goalContext(base: GoalContext?, targets: DailyTargets?, eaten: Macros,
                            mealsLeft: Int) -> GoalContext? {
        guard let base, let targets else { return base }
        let meals = Double(max(mealsLeft, 1))
        func share(_ target: Double, _ eaten: Double, _ usual: Double) -> Double {
            min(max((target - eaten) / meals, usual * lowest), usual * highest)
        }
        let usual = base.perMeal
        let perMeal = Macros(kcal: share(Double(targets.kcal), eaten.kcal, usual.kcal),
                             protein: share(Double(targets.protein), eaten.protein, usual.protein),
                             carbs: share(Double(targets.carbs), eaten.carbs, usual.carbs),
                             fat: share(Double(targets.fat), eaten.fat, usual.fat))
        return GoalContext(goal: base.goal, perMeal: perMeal)
    }

    /// How far the per-meal target may fall or rise from the usual third.
    static let lowest = 0.6
    static let highest = 1.6
}
