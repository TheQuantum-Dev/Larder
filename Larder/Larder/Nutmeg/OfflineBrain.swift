//
//  OfflineBrain.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import Foundation
import NaturalLanguage

/// What someone is asking Nutmeg for.
nonisolated enum NutmegIntent: Equatable, Sendable {
    case greeting, thanks, help
    case whatCanIMake, quick, cheap, noStove, healthier
    case withIngredients([String])
    case aboutRecipe(String)
    case pantryContents, savings, streak, budget
    case offTopic
}

/// Nutmeg without a language model: works on every phone, entirely offline.
/// It recognises a fixed set of questions and answers them from real app
/// data. It isn't free-form AI and doesn't pretend to be; for anything it
/// doesn't recognise, it says what it can help with instead of guessing.
nonisolated struct OfflineBrain: Sendable {
    /// Catches wordings the rules miss by similarity to example questions.
    /// Injected so tests can run without the system's sentence embeddings.
    var fallback: @Sendable (String) -> NutmegIntent?

    init(fallback: @escaping @Sendable (String) -> NutmegIntent? = IntentEmbeddings.closest) {
        self.fallback = fallback
    }

    func reply(to message: String, in kitchen: KitchenSnapshot) -> NutmegReply {
        answer(intent(for: message), in: kitchen)
    }

    // MARK: - Understanding

    func intent(for message: String) -> NutmegIntent {
        let text = " " + IngredientCatalog.key(for: message) + " "
        let words = text.split(separator: " ").map(String.init)

        if words.count <= 4, has(text, ["hi", "hello", "hey", "yo", "hiya", "morning", "evening"]) { return .greeting }
        if has(text, ["thank", "thanks", "thx", "cheers", "ty"]) { return .thanks }
        if has(text, ["help", "what can you do", "how do you work", "what do you do"]) { return .help }

        if let recipe = mentionedRecipe(in: text) { return .aboutRecipe(recipe) }
        if has(text, ["saved", "saving", "savings", "save money so far", "how much have i save"]) { return .savings }
        if has(text, ["streak"]) { return .streak }
        if has(text, ["cheap", "cheaper", "cheapest", "broke", "inexpensive", "low cost", "on a budget", "afford"]) { return .cheap }
        if has(text, ["budget", "spent", "spend", "spending"]) { return .budget }
        if has(text, ["what do i have", "what have i got", "what s in my", "whats in my", "in my pantry", "in my fridge",
                      "in my kitchen", "running low", "do i have", "left in"]) {
            let ingredients = mentionedIngredients(in: message)
            return ingredients.isEmpty ? .pantryContents : .withIngredients(ingredients)
        }

        let ingredients = mentionedIngredients(in: message)
        if !ingredients.isEmpty { return .withIngredients(ingredients) }

        if has(text, ["quick", "quicker", "fast", "faster", "hurry", "rush", "short on time", "no time", "minute", "min"]) { return .quick }
        if has(text, ["no stove", "without a stove", "microwave", "dorm", "no cooking", "no cook", "toaster", "kettle"]) {
            return .noStove
        }
        if has(text, ["healthy", "healthier", "light", "lighter", "veggie", "vegetable", "green", "nutritious", "fresh"]) {
            return .healthier
        }
        if has(text, ["what can i make", "what should i", "make", "cook", "dinner", "lunch", "breakfast", "hungry",
                      "eat", "recipe", "idea", "tonight", "craving", "food", "meal", "snack"]) {
            return .whatCanIMake
        }
        return fallback(message) ?? .offTopic
    }

    /// Whole-word or whole-phrase matches against the normalised message.
    private func has(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains { text.contains(" " + IngredientCatalog.key(for: $0) + " ") }
    }

    private func mentionedRecipe(in text: String) -> String? {
        RecipeStore.all
            .map { ($0.id, " " + IngredientCatalog.key(for: $0.title) + " ") }
            .sorted { $0.1.count > $1.1.count }
            .first { text.contains($0.1) }?.0
    }

    private func mentionedIngredients(in message: String) -> [String] {
        IngredientCatalog.find(inText: message).map(\.id).sorted()
    }

    // MARK: - Relevant recipes

    /// The recipes that fit what was asked, most relevant first. The offline
    /// answers use it directly, and the model is handed this list, so "a
    /// cheaper one" really does get the cheap recipes in front of it.
    func candidates(for intent: NutmegIntent, in kitchen: KitchenSnapshot) -> [RecipeMatch] {
        let all = kitchen.matches
        switch intent {
        case .quick:
            return all.filter { $0.recipe.minutes <= RecipeFilter.quickMinutes }.sorted { $0.recipe.minutes < $1.recipe.minutes }
        case .cheap:
            return all.sorted { $0.recipe.costPerServing < $1.recipe.costPerServing }
        case .noStove:
            return all.filter(\.recipe.needsNoStove)
        case .healthier:
            return all.filter(\.recipe.healthy)
        case .withIngredients(let ids):
            let wanted = Set(ids)
            return all
                .filter { match in match.recipe.ingredients.contains { !wanted.isDisjoint(with: [$0.id] + $0.alternatives) } }
                .sorted { ($0.isReady ? 0 : 1, $0.missing.count) < ($1.isReady ? 0 : 1, $1.missing.count) }
        case .aboutRecipe(let id):
            return all.filter { $0.recipe.id == id } + all.filter { $0.recipe.id != id }
        default:
            return all
        }
    }

    // MARK: - Answering

    func answer(_ intent: NutmegIntent, in kitchen: KitchenSnapshot) -> NutmegReply {
        switch intent {
        case .greeting:
            return NutmegReply("Hi! I'm peeking at your kitchen right now. Ask me what you can make, or how your week's going.")
        case .thanks:
            return NutmegReply("Anytime! Happy cooking.")
        case .help:
            return NutmegReply("I can find recipes from what you've got, tell you what's missing for one, and check your savings, streak and budget. Try \"something quick\" or \"what can I make with eggs?\"")
        case .whatCanIMake:
            return suggestions(from: kitchen.matches, in: kitchen,
                               ready: "You can make %d things right now. Here are my top picks:",
                               close: "Nothing's fully ready yet, but these are close:")
        case .quick:
            return suggestions(from: candidates(for: .quick, in: kitchen), in: kitchen,
                               ready: "Quick ones you can make right now:",
                               close: "Nothing quick is fully ready, but these are close:")
        case .cheap:
            return suggestions(from: candidates(for: .cheap, in: kitchen), in: kitchen,
                               ready: "The cheapest things you can make right now:",
                               close: "Nothing cheap is fully ready, but these cost next to nothing:")
        case .noStove:
            return suggestions(from: candidates(for: .noStove, in: kitchen), in: kitchen,
                               ready: "No stove needed for these:",
                               close: "These don't need a stove, and they're close:")
        case .healthier:
            return suggestions(from: candidates(for: .healthier, in: kitchen), in: kitchen,
                               ready: "Lighter ones you can make right now:",
                               close: "These lighter ones are close:")
        case .withIngredients(let ids):
            return withIngredients(ids, in: kitchen)
        case .aboutRecipe(let id):
            return aboutRecipe(id, in: kitchen)
        case .pantryContents:
            return pantryContents(kitchen)
        case .savings:
            return savings(kitchen)
        case .streak:
            return streak(kitchen)
        case .budget:
            return budget(kitchen)
        case .offTopic:
            return NutmegReply("I'm best with food things: what to cook, what's in your pantry, and how your week's going. Want some ideas for tonight?")
        }
    }

    /// Ready recipes first; if none, the closest ones, with what they need.
    private func suggestions(from pool: [RecipeMatch], in kitchen: KitchenSnapshot,
                             ready readyLine: String, close closeLine: String) -> NutmegReply {
        if kitchen.pantry.isEmpty {
            return NutmegReply("Your pantry's empty right now, so I can't cook from it yet! Add a few things in the Pantry tab and I'll get picky for you.")
        }
        let ready = pool.filter(\.isReady)
        if !ready.isEmpty {
            let text = readyLine.contains("%d") ? String(format: readyLine, ready.count) : readyLine
            return NutmegReply(text, recipeIDs: ready.map(\.recipe.id))
        }
        let close = pool.filter { $0.missing.count <= 2 }.sorted { $0.missing.count < $1.missing.count }
        guard let best = close.first else {
            return NutmegReply("Nothing like that is close with what you've got. Want to see everything that is?")
        }
        return NutmegReply("\(closeLine) \(best.recipe.title) only needs \(Self.list(names(best.missing))).",
                           recipeIDs: close.map(\.recipe.id))
    }

    private func withIngredients(_ ids: [String], in kitchen: KitchenSnapshot) -> NutmegReply {
        let names = ids.compactMap { IngredientCatalog.ingredient(withID: $0)?.name.lowercased() }
        let using = candidates(for: .withIngredients(ids), in: kitchen)
        guard !using.isEmpty else {
            return NutmegReply("I don't have a recipe with \(Self.list(names)) yet. Want to see what else you can make?")
        }
        let missingFromPantry = ids.filter { !kitchen.pantryIDs.contains($0) }
            .compactMap { IngredientCatalog.ingredient(withID: $0)?.name.lowercased() }
        let intro = missingFromPantry.isEmpty
            ? "With \(Self.list(names)), you could make:"
            : "You don't have \(Self.list(missingFromPantry)) in your pantry yet, but with it you could make:"
        return NutmegReply(intro, recipeIDs: using.map(\.recipe.id))
    }

    private func aboutRecipe(_ id: String, in kitchen: KitchenSnapshot) -> NutmegReply {
        guard let recipe = RecipeStore.recipe(withID: id) else { return answer(.whatCanIMake, in: kitchen) }
        guard let match = kitchen.match(for: id) else {
            return NutmegReply("\(recipe.title) doesn't fit what you eat, so I've left it out. Want something similar?")
        }
        if match.isReady {
            return NutmegReply("You've got everything for \(recipe.title)! It's about \(recipe.minutes) minutes and \(recipe.costText) a serving.",
                               recipeIDs: [id])
        }
        return NutmegReply("For \(recipe.title) you're missing \(Self.list(names(match.missing))). Everything else is already in your kitchen.",
                           recipeIDs: [id])
    }

    private func pantryContents(_ kitchen: KitchenSnapshot) -> NutmegReply {
        guard !kitchen.pantry.isEmpty else {
            return NutmegReply("Your pantry's empty right now. Tap + in the Pantry tab and I'll keep track of what you add.")
        }
        let shown = kitchen.pantry.prefix(6).map { item in
            item.amount.map { "\(item.name.lowercased()) (\($0))" } ?? item.name.lowercased()
        }
        let more = kitchen.pantry.count > shown.count ? ", and \(kitchen.pantry.count - shown.count) more" : ""
        let count = kitchen.pantry.count == 1 ? "1 thing" : "\(kitchen.pantry.count) things"
        return NutmegReply("You've got \(count): \(shown.joined(separator: ", "))\(more).")
    }

    private func savings(_ kitchen: KitchenSnapshot) -> NutmegReply {
        guard kitchen.mealCount > 0 else {
            return NutmegReply("Nothing saved yet, because nothing's been cooked yet! Make your first meal and I'll start counting.")
        }
        // "…of it this week" only adds something when it's a different number.
        let week = kitchen.weekSaved > 0 && kitchen.totalSaved - kitchen.weekSaved >= 0.01
            ? ", \(Money.text(kitchen.weekSaved)) of it this week" : ""
        return NutmegReply("You've saved about \(Money.text(kitchen.totalSaved)) so far\(week), compared with ordering out. That's \(kitchen.mealCount) \(kitchen.mealCount == 1 ? "meal" : "meals") from your own kitchen!")
    }

    private func streak(_ kitchen: KitchenSnapshot) -> NutmegReply {
        let best = kitchen.bestStreak > kitchen.streak.days ? " Your best is \(kitchen.bestStreak) days." : ""
        switch kitchen.streak {
        case .none:
            return NutmegReply("No streak going right now. Cook anything today and it starts at 1!\(best)")
        case .safe(let days):
            return NutmegReply("You're on a \(days)-day streak, and you've already cooked today. Nice!\(best)")
        case .atRisk(let days):
            let quick = kitchen.readyMatches.filter { $0.recipe.minutes <= RecipeFilter.quickMinutes }.map(\.recipe.id)
            return NutmegReply("You're on a \(days)-day streak! Anything you cook today keeps it going.\(quick.isEmpty ? "" : " Here's something quick:")\(best)",
                               recipeIDs: quick)
        }
    }

    private func budget(_ kitchen: KitchenSnapshot) -> NutmegReply {
        guard kitchen.weeklyBudget > 0 else {
            return NutmegReply("You haven't set a weekly budget yet. You can add one in Settings, and I'll keep an eye on it.")
        }
        let budget = Double(kitchen.weeklyBudget)
        let spent = "You've cooked about \(Money.text(kitchen.weekCost)) worth of ingredients this week"
        if kitchen.weekCost <= budget {
            return NutmegReply("\(spent), with \(Money.text(budget - kitchen.weekCost)) left of your \(Money.text(budget)) budget.")
        }
        return NutmegReply("\(spent), a little over your \(Money.text(budget)) budget. That's okay, these are rough numbers.")
    }

    private func names(_ lines: [RecipeIngredient]) -> [String] {
        lines.map { IngredientCatalog.ingredient(withID: $0.id)?.name.lowercased() ?? $0.id }
    }

    /// "eggs", "eggs and rice", "eggs, rice and cheese".
    static func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        default: return items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }
}

/// The similarity fallback: compares a message with a few example
/// questions per intent using Apple's on-device sentence embeddings.
nonisolated enum IntentEmbeddings {
    /// Cosine distance under which a message counts as "the same question".
    static let threshold = 0.85

    private static let examples: [(NutmegIntent, String)] = [
        (.whatCanIMake, "what should I have for dinner"),
        (.whatCanIMake, "give me something to cook"),
        (.quick, "I don't have much time to cook"),
        (.cheap, "I'm low on money this week"),
        (.healthier, "I want to eat better"),
        (.pantryContents, "what food is left"),
        (.savings, "how much money has cooking saved me"),
        (.budget, "how is my spending going"),
        (.help, "how does this app work"),
    ]

    static func closest(_ message: String) -> NutmegIntent? {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }
        let scored = examples.map { ($0.0, embedding.distance(between: message.lowercased(), and: $0.1)) }
        guard let best = scored.min(by: { $0.1 < $1.1 }), best.1 < threshold else { return nil }
        return best.0
    }
}
