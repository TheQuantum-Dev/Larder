//
//  BudgetInsights.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

/// The numbers behind the budget insights screen, worked out from the meals
/// marked as made. Nothing here is a receipt: each figure is the rough
/// ingredient cost the recipe already carried, added up by week.
struct BudgetInsights: Equatable {
    struct Week: Equatable, Identifiable {
        let start: Date
        let cost: Double
        let meals: Int
        var id: Date { start }
    }

    struct BestSave: Equatable {
        let title: String
        let emoji: String
        let saved: Double
    }

    enum Standing: Equatable {
        case noBudget
        case under(left: Double)
        case over(by: Double)
    }

    /// Estimated ingredient cost of what was cooked this week.
    let weekCost: Double
    let weekSaved: Double
    let weekMeals: Int
    /// The weekly budget in whole dollars, 0 when none is set.
    let budget: Int
    /// The last few weeks, oldest first, ending with this one.
    let weeks: [Week]
    let mealCount: Int
    let totalSaved: Double
    /// Nil until at least one meal has been made.
    let averageCostPerServing: Double?
    let bestSave: BestSave?

    var standing: Standing {
        guard budget > 0 else { return .noBudget }
        let limit = Double(budget)
        return weekCost <= limit ? .under(left: limit - weekCost) : .over(by: weekCost - limit)
    }

    /// How full the budget bar is, held at 1 once it's passed.
    var budgetProgress: Double {
        guard budget > 0 else { return 0 }
        return min(1, weekCost / Double(budget))
    }

    /// The short version, for a card subtitle: "$12.00 left this week".
    var standingHeadline: String? {
        switch standing {
        case .noBudget: nil
        case .under(let left): "\(Money.text(left)) left this week"
        case .over(let by): "\(Money.text(by)) over this week"
        }
    }

    /// One friendly line about where the week stands. Going over is never
    /// framed as a failure, because every figure here is a rough guess.
    var standingText: String? {
        guard let headline = standingHeadline else { return nil }
        if case .over = standing { return headline + ". That's okay, these are rough numbers." }
        return headline
    }

    static func compute(from meals: [CookedMeal],
                        budget: Int,
                        weekCount: Int = 4,
                        now: Date = Date(),
                        calendar: Calendar = .current) -> BudgetInsights {
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.startOfDay(for: now)

        var weeks: [Week] = []
        for offset in stride(from: weekCount - 1, through: 0, by: -1) {
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { continue }
            let inWeek = meals.filter { $0.cookedAt >= start && $0.cookedAt < end }
            weeks.append(Week(start: start, cost: inWeek.reduce(0) { $0 + $1.cost }, meals: inWeek.count))
        }

        let current = weeks.last
        let thisWeek = meals.filter { $0.cookedAt >= thisWeekStart }
        let servings = meals.reduce(0) { $0 + $1.servings }
        let best = meals.max { $0.saved < $1.saved }

        return BudgetInsights(
            weekCost: current?.cost ?? 0,
            weekSaved: thisWeek.reduce(0) { $0 + $1.saved },
            weekMeals: current?.meals ?? 0,
            budget: budget,
            weeks: weeks,
            mealCount: meals.count,
            totalSaved: meals.reduce(0) { $0 + $1.saved },
            averageCostPerServing: servings > 0 ? meals.reduce(0) { $0 + $1.cost } / Double(servings) : nil,
            bestSave: best.flatMap { $0.saved > 0 ? BestSave(title: $0.title, emoji: $0.emoji, saved: $0.saved) : nil }
        )
    }

    /// The cheapest recipes that can be made from the pantry right now, for
    /// when the week's budget is getting tight.
    static func cheapestReady(from matches: [RecipeMatch], limit: Int = 3) -> [RecipeMatch] {
        matches
            .filter(\.isReady)
            .sorted { $0.recipe.costPerServing < $1.recipe.costPerServing }
            .prefix(limit)
            .map { $0 }
    }
}
