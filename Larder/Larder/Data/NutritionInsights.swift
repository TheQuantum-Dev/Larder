//
//  NutritionInsights.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation

/// What the meals cooked in Larder add up to, today and over the last week.
/// It only knows about meals cooked here, so it says so wherever it's shown.
struct NutritionInsights: Equatable {
    struct Day: Equatable, Identifiable {
        let start: Date
        let total: Macros
        let meals: Int

        var id: Date { start }
    }

    let today: Macros
    let mealsToday: Int
    /// The last seven days, oldest first, ending today.
    let days: [Day]
    /// Averaged over only the days something was cooked, or nil if nothing was.
    let dailyAverage: Macros?

    var mealsThisWeek: Int { days.reduce(0) { $0 + $1.meals } }

    static func compute(from meals: [CookedMeal], now: Date = Date(),
                        calendar: Calendar = .current) -> NutritionInsights {
        let todayStart = calendar.startOfDay(for: now)
        let starts = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: todayStart) }

        var totals: [Date: Macros] = [:]
        var counts: [Date: Int] = [:]
        for meal in meals {
            guard let macros = meal.nutrition else { continue }
            let day = calendar.startOfDay(for: meal.cookedAt)
            totals[day, default: .zero] = totals[day, default: .zero] + macros
            counts[day, default: 0] += 1
        }

        let days = starts.map { Day(start: $0, total: totals[$0] ?? .zero, meals: counts[$0] ?? 0) }
        let cooked = days.filter { $0.meals > 0 }
        let average = cooked.isEmpty
            ? nil
            : cooked.reduce(Macros.zero) { $0 + $1.total } * (1 / Double(cooked.count))
        let today = days.last
        return NutritionInsights(today: today?.total ?? .zero, mealsToday: today?.meals ?? 0,
                                 days: days, dailyAverage: average)
    }
}
