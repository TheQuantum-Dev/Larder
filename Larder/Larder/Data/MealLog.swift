//
//  MealLog.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation
import SwiftData

/// How the meals so far add up.
struct MealStats: Equatable {
    let mealCount: Int
    let mealsThisWeek: Int
    let totalSaved: Double

    static func compute(from meals: [CookedMeal], now: Date = Date(), calendar: Calendar = .current) -> MealStats {
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let thisWeek = meals.filter { week?.contains($0.cookedAt) ?? false }
        return MealStats(mealCount: meals.count,
                         mealsThisWeek: thisWeek.count,
                         totalSaved: meals.reduce(0) { $0 + $1.saved })
    }
}

enum MealLog {
    static func meals(in context: ModelContext) -> [CookedMeal] {
        let sort = [SortDescriptor(\CookedMeal.cookedAt)]
        return (try? context.fetch(FetchDescriptor<CookedMeal>(sortBy: sort))) ?? []
    }

    static func count(in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<CookedMeal>())) ?? 0
    }

    @discardableResult
    static func record(_ summary: MealSummary, at date: Date = Date(), in context: ModelContext) -> CookedMeal {
        let meal = CookedMeal(recipeID: summary.recipeID, title: summary.title, emoji: summary.emoji,
                              cookedAt: date, servings: summary.servings,
                              cost: summary.totalCost, saved: summary.saved,
                              nutrition: summary.nutritionEaten, servingsEaten: summary.servingsEaten)
        context.insert(meal)
        try? context.save()
        return meal
    }
}
