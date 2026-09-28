//
//  KitchenSnapshot.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import Foundation

/// Everything Nutmeg can see, frozen at the moment a message is sent. Both
/// chat engines read only this, never the database, so an answer is always
/// about one consistent picture of the kitchen, and the engines can run off
/// the main thread safely.
nonisolated struct KitchenSnapshot: Sendable {
    struct Item: Sendable, Equatable {
        let id: String
        let name: String
        let emoji: String
        /// "6", "500 g" and so on; nil when no amount was set.
        let amount: String?
        /// The same amount as a number and a unit, for adding to it.
        var quantity: Double? = nil
        var unit: String? = nil
    }

    /// Something cooked in Larder today.
    struct MealLine: Sendable, Equatable {
        let title: String
        let time: Date
        /// What was eaten of it; nil for meals logged before numbers were kept.
        let macros: Macros?
    }

    /// Whether online recipes can be offered right now, and if not, why not.
    enum OnlineAvailability: Sendable, Equatable {
        /// This build can't look recipes up.
        case unavailable
        /// The person hasn't switched them on.
        case off
        /// A lookup is on its way.
        case looking
        case ready
        /// The day's free lookups are used up.
        case resting
        case offline
    }

    var pantry: [Item] = []
    /// Every recipe that fits the person's diet, best match first.
    var matches: [RecipeMatch] = []
    var mealCount = 0
    var mealsThisWeek = 0
    var totalSaved = 0.0
    var weekSaved = 0.0
    var streak = CookingStreak.Status.none
    var bestStreak = 0
    /// Whole dollars; 0 means no budget set.
    var weeklyBudget = 0
    /// Rough ingredient cost of what was cooked this week.
    var weekCost = 0.0
    var mealGoal = 0
    var priorities: Set<Priority> = []
    /// False when the person chose "just cook": Nutmeg keeps to cooking and
    /// leaves every calorie and macro number out.
    var showsNutrition = true
    var goal: FitnessGoal?
    var targets: DailyTargets?
    /// What was cooked today in Larder, and the average on days something was.
    var today = Macros.zero
    var mealsToday = 0
    var dailyAverage: Macros?

    var mealsTodayList: [MealLine] = []
    var online = OnlineAvailability.unavailable
    /// Which meal it is now, so ideas for it come first.
    var slot = MealSlot.dinner
    /// The shopping list.
    var shopping: [ShoppingLine] = []

    /// One thing on the shopping list.
    struct ShoppingLine: Sendable, Equatable {
        let name: String
        let amount: String?
        let isBought: Bool
    }

    /// Pantry items that are nearly out, going by their amounts.
    var lowItems: [Item] {
        pantry.filter { PantryAmount.isRunningLow(Amount(quantity: $0.quantity, unit: $0.unit)) }
    }

    var readyMatches: [RecipeMatch] { matches.filter(\.isReady) }
    var pantryIDs: Set<String> { Set(pantry.map(\.id)) }

    func match(for recipeID: String) -> RecipeMatch? {
        matches.first { $0.recipe.id == recipeID }
    }
}

extension KitchenSnapshot {
    /// Builds a snapshot from the live data. Runs on the main actor, where
    /// SwiftData's objects live.
    static func capture(pantry: [PantryItem], meals: [CookedMeal], profile: Profile,
                        weeklyBudget: Int, mealGoal: Int, shopping: [ShoppingItem] = [], online: [Recipe] = [],
                        onlineStatus: OnlineAvailability = .unavailable, onlineOnly: Bool = false,
                        hiddenOnline: Set<String> = [], now: Date = Date()) -> KitchenSnapshot {
        let stats = MealStats.compute(from: meals, now: now)
        let budget = BudgetInsights.compute(from: meals, budget: weeklyBudget, now: now)
        let dates = meals.map(\.cookedAt)
        let nutrition = NutritionInsights.compute(from: meals, now: now)
        return KitchenSnapshot(
            pantry: pantry.map { Item(id: $0.ingredientID, name: $0.name, emoji: $0.emoji, amount: $0.amountText,
                                      quantity: $0.quantity, unit: $0.unit) },
            // Larder's own recipes and any found online, ranked together the
            // same way the Recipes tab ranks them.
            matches: RecipePool.matches(bundled: RecipeStore.all, online: online, onlineOnly: onlineOnly,
                                        hidden: hiddenOnline) { recipes in
                RecipeMatcher.matches(recipes: recipes, pantry: Set(pantry.map(\.ingredientID)),
                                      diets: profile.dietSet, priorities: profile.prioritySet,
                                      cooking: profile.cookingSet, goal: profile.goalContext, maxMissing: .max)
            },
            mealCount: stats.mealCount,
            mealsThisWeek: stats.mealsThisWeek,
            totalSaved: stats.totalSaved,
            weekSaved: budget.weekSaved,
            streak: CookingStreak.status(from: dates, now: now),
            bestStreak: CookingStreak.best(from: dates),
            weeklyBudget: weeklyBudget,
            weekCost: budget.weekCost,
            mealGoal: mealGoal,
            priorities: profile.prioritySet,
            showsNutrition: profile.showsNutrition,
            goal: profile.fitnessGoal,
            targets: profile.dailyTargets,
            today: nutrition.today,
            mealsToday: nutrition.mealsToday,
            dailyAverage: nutrition.dailyAverage,
            mealsTodayList: meals.filter { Calendar.current.isDate($0.cookedAt, inSameDayAs: now) }
                .sorted { $0.cookedAt < $1.cookedAt }
                .map { MealLine(title: $0.title, time: $0.cookedAt, macros: $0.nutrition) },
            online: onlineStatus,
            slot: MealPlan.slot(at: now),
            shopping: shopping.map { ShoppingLine(name: $0.name, amount: $0.amountText, isBought: $0.isBought) })
    }
}

/// One answer from Nutmeg: what to say, plus any recipes to show as cards,
/// quick replies to tap, or a pantry change to confirm. Recipe ids are checked
/// against the bundled book (or are ids of recipes found online, which only
/// ever come from the kitchen snapshot), so neither engine can ever put a
/// made-up recipe in front of someone.
nonisolated struct NutmegReply: Equatable, Sendable {
    static let maxRecipes = 3

    let text: String
    let recipeIDs: [String]
    var quickReplies: [String] = []
    var pantryChange: PantryCommand?
    /// What Nutmeg offered to do next, so "yes" can mean something.
    var offer: FollowUp?
    /// Every recipe that fit, beyond the few shown, for "show me more".
    var pool: [String] = []
    /// Things to put on the shopping list right away (asked for outright).
    var listAdditions: [ShoppingEntry] = []
    /// What the reply listed, so "how much of each?" knows what it means.
    var topic: ReplyTopic?

    enum ReplyTopic: Equatable, Sendable { case shoppingList, pantry }

    init(_ text: String, recipeIDs: [String] = [], quickReplies: [String] = [], pantryChange: PantryCommand? = nil,
         offer: FollowUp? = nil, pool: [String] = [], listAdditions: [ShoppingEntry] = []) {
        self.text = text
        self.recipeIDs = Self.valid(recipeIDs)
        self.quickReplies = quickReplies
        self.pantryChange = pantryChange
        self.offer = offer
        self.pool = pool
        self.listAdditions = listAdditions
    }

    /// Known ids only, no repeats, at most three.
    static func valid(_ ids: [String]) -> [String] {
        var seen: Set<String> = []
        return ids
            .filter { (RecipeStore.recipe(withID: $0) != nil || $0.hasPrefix(OnlineRecipeMapper.idPrefix))
                && seen.insert($0).inserted }
            .prefix(maxRecipes)
            .map { $0 }
    }
}

/// Something Nutmeg offered, waiting on a yes or no.
nonisolated enum FollowUp: Equatable, Sendable {
    /// Put these on the shopping list.
    case addToList([ShoppingEntry])
    /// Some ideas for what to cook.
    case ideas
}
