//
//  ModelBrain.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import Foundation
import FoundationModels
import os

/// Nutmeg on phones with Apple Intelligence: the on-device model, handed a
/// short summary of the kitchen with every question. It can understand
/// anything, but it can only recommend recipes from that summary (the bundled
/// book), and never writes cooking steps. If anything goes wrong, or it's
/// slow, that one answer comes from the offline Nutmeg.
///
/// The summary goes in the prompt rather than behind tools on purpose: each
/// tool call is another full round with the model, and one round is much
/// faster than four. A fresh session per question, carrying the last few
/// exchanges, also keeps the model's small context window from ever filling.
actor ModelBrain: NutmegBrain {
    static var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    /// Nobody should watch dots for long: past this, the offline answer wins.
    static let timeLimit: Duration = .seconds(20)
    /// How many recipes the summary lists, best matches first.
    static let recipesInSummary = 12
    /// Earlier exchanges carried into each question, for follow-ups like "and a cheaper one?".
    static let historyLength = 3

    private let offline = OfflineBrain()
    private var warmSession: LanguageModelSession?
    private var history: [(asked: String, answered: String)] = []

    func reply(to message: String, in kitchen: KitchenSnapshot) async -> NutmegReply {
        // Numbers have to be exactly right, so questions about them are
        // answered straight from the app's data. The model handles the rest.
        let intent = offline.intent(for: message)
        if Self.answersFromFacts(intent) {
            let reply = offline.answer(intent, in: kitchen)
            remember(message, reply.text)
            return reply
        }
        let session = warmSession ?? Self.makeSession()
        warmSession = nil
        do {
            // The offline brain decides which recipes are relevant; the model
            // decides how to say it.
            let candidates = offline.candidates(for: intent, in: kitchen)
            let prompt = Self.prompt(for: message, kitchen: kitchen, intent: intent, candidates: candidates,
                                     history: history)
            let answer = try await respond(session, to: prompt)
            let reply = NutmegReply(answer.text, recipeIDs: Self.recipeIDs(forTitles: answer.recipes))
            remember(message, reply.text)
            return reply
        } catch {
            Self.log.error("Model answer failed, using offline Nutmeg: \(String(describing: error), privacy: .public)")
            let reply = offline.reply(to: message, in: kitchen)
            remember(message, reply.text)
            return reply
        }
    }

    /// Loads the model ahead of the first question, so it answers sooner.
    func prewarm() {
        let session = warmSession ?? Self.makeSession()
        warmSession = session
        session.prewarm()
    }

    private func remember(_ asked: String, _ answered: String) {
        history.append((asked, answered))
        history = Array(history.suffix(Self.historyLength))
    }

    /// Savings, streak, budget and the pantry list are facts, not
    /// conversation: they come from the offline Nutmeg, word for word.
    static func answersFromFacts(_ intent: NutmegIntent) -> Bool {
        switch intent {
        case .savings, .streak, .budget, .pantryContents, .caloriesToday, .proteinToday, .ingredientNutrition: true
        default: false
        }
    }

    struct TimedOut: Error {}

    private func respond(_ session: LanguageModelSession, to prompt: String) async throws -> NutmegAnswer {
        try await withThrowingTaskGroup(of: NutmegAnswer.self) { group in
            group.addTask { try await session.respond(to: prompt, generating: NutmegAnswer.self).content }
            group.addTask {
                try await Task.sleep(for: Self.timeLimit)
                throw TimedOut()
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw TimedOut() }
            return first
        }
    }

    static let log = Logger(subsystem: "com.joshuasamuel.Larder", category: "Nutmeg")

    private static func makeSession() -> LanguageModelSession {
        LanguageModelSession(instructions: instructions)
    }

    static let instructions = """
        You are Nutmeg, a small, warm, curious pantry helper inside Larder, an app that helps students \
        cook from what they already have on a tight budget.
        Each message comes with the person's pantry and a list of recipes to choose from (most \
        relevant first). Answer only from that. Never guess what's in their kitchen.
        Only suggest recipes from the list, by their exact title, and put up to three of those titles \
        in recipes. Never invent a recipe. Never mention ids or list numbers.
        Never write cooking steps, instructions, temperatures or timings of your own. The app has \
        checked steps; say they can tap the recipe for them.
        Don't mention numbers about their savings, streak or budget; the app answers those itself.
        Stay on food, cooking plans, their pantry and the app. For anything else, say kindly that \
        you're best with food things and offer an idea for tonight.
        Quote calories and protein only exactly as listed for a recipe; never work out or invent numbers. \
        Don't give medical, allergy or dieting advice.
        Keep answers to one to three short sentences. Be encouraging, never judgmental about money, \
        an empty fridge, or a broken streak.
        """

    /// The kitchen summary plus the question: everything the model sees.
    static func prompt(for message: String, kitchen: KitchenSnapshot, intent: NutmegIntent = .whatCanIMake,
                       candidates: [RecipeMatch], history: [(asked: String, answered: String)]) -> String {
        var lines: [String] = []
        let pantry = kitchen.pantry.map { item in item.amount.map { "\(item.name) (\($0))" } ?? item.name }
        lines.append("Pantry: " + (pantry.isEmpty ? "empty." : pantry.joined(separator: ", ") + "."))
        if kitchen.showsNutrition, let goal = kitchen.goal {
            lines.append("Their goal: \(goal.title.lowercased()). Favor recipes that suit it.")
        }
        if candidates.isEmpty {
            lines.append("Recipes to choose from: none fit this.")
        } else {
            lines.append("Recipes to choose from, most relevant first:")
            lines += candidates.prefix(recipesInSummary).map { recipeLine($0, nutrition: kitchen.showsNutrition) }
        }
        if let focus = focus(for: intent) { lines.append(focus) }
        if !history.isEmpty {
            lines.append("Earlier in this chat:")
            for exchange in history {
                lines.append("Person: \(exchange.asked)")
                lines.append("Nutmeg: \(exchange.answered)")
            }
        }
        lines.append("Their message: \(message)")
        return lines.joined(separator: "\n")
    }

    /// What they seem to want, in plain words, so a small model answers the
    /// question actually asked (a "cheaper one?" follow-up, say).
    static func focus(for intent: NutmegIntent) -> String? {
        switch intent {
        case .quick: return "They want something quick; the list is sorted quickest first."
        case .cheap: return "They want something cheap; the list is sorted cheapest first. Mention the cost."
        case .noStove: return "They can't use a stove; every recipe in the list works without one."
        case .healthier: return "They want something on the lighter side."
        case .highProtein: return "They want lots of protein; the list is sorted most protein first. Mention the protein."
        case .lowCalorie: return "They want something lower in calories; the list is sorted lightest first. Mention the calories."
        case .hearty: return "They want something filling; the list is sorted biggest first. Mention the calories."
        case .withIngredients(let ids):
            let names = ids.compactMap { IngredientCatalog.ingredient(withID: $0)?.name.lowercased() }
            return "They want to use \(OfflineBrain.list(names))."
        case .aboutRecipe(let id):
            return RecipeStore.recipe(withID: id).map { "They're asking about \($0.title); it's first in the list." }
        default: return nil
        }
    }

    /// "- Grilled cheese: 10 min, about $1.28 a serving, needs cheese"
    static func recipeLine(_ match: RecipeMatch, nutrition: Bool = false) -> String {
        let recipe = match.recipe
        var parts = ["\(recipe.minutes) min", "\(recipe.costText) a serving"]
        if match.isReady {
            parts.append("ready now")
        } else {
            let names = match.missing.map { IngredientCatalog.ingredient(withID: $0.id)?.name.lowercased() ?? $0.id }
            parts.append("needs " + OfflineBrain.list(names))
        }
        if nutrition {
            parts.append("about \(recipe.nutrition.roundedKcal) kcal and \(recipe.nutrition.roundedProtein) g protein")
        }
        if recipe.needsNoStove { parts.append("no stove") }
        if recipe.healthy { parts.append("on the lighter side") }
        return "- \(recipe.title): " + parts.joined(separator: ", ")
    }

    /// Titles the model picked, back to ids. Exact titles first; a title that
    /// only contains or is contained in one still counts, since small models
    /// sometimes trim words. Anything unrecognised is dropped.
    static func recipeIDs(forTitles titles: [String]) -> [String] {
        titles.compactMap { title in
            let key = IngredientCatalog.key(for: title)
            guard !key.isEmpty else { return nil }
            let recipes = RecipeStore.all
            if let exact = recipes.first(where: { IngredientCatalog.key(for: $0.title) == key }) { return exact.id }
            return recipes.first { recipe in
                let recipeKey = IngredientCatalog.key(for: recipe.title)
                return recipeKey.contains(key) || key.contains(recipeKey)
            }?.id
        }
    }
}

/// The structured answer the model gives: what to say, and which recipes to
/// show as cards underneath.
@Generable
nonisolated struct NutmegAnswer {
    @Guide(description: "What Nutmeg says: one to three short, warm sentences.")
    var text: String

    @Guide(description: "Exact titles of up to three recipes from the list to show as cards. Empty if none fit.")
    var recipes: [String]
}
