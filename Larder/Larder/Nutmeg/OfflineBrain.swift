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
    case highProtein, lowCalorie, hearty
    case caloriesToday, proteinToday, eatenToday
    /// Today's carbs or fat ("how much fat have I eaten").
    case macroToday(Macro)
    /// About Nutmeg himself: who he is, who made him.
    case aboutNutmeg, creator
    /// "What's my name?": Larder has no accounts, so he doesn't know.
    case userName
    case ingredientNutrition(String)
    /// "Add 6 eggs", "I ran out of milk": shown as a card to confirm.
    case pantryChange(PantryCommand)
    /// Something new from the recipes found online.
    case onlineIdea
    /// "What should I eat?": Nutmeg asks what they're in the mood for.
    case moodQuestion
    case surprise
    case craving(Craving)
    /// "What's on my shopping list?"
    case shoppingList
    /// "Add milk to my shopping list", "I need to buy eggs".
    case addToShoppingList([ShoppingEntry])
    /// "What's running low?"
    case runningLow
    case offTopic
}

/// A macro Nutmeg can add up for today.
nonisolated enum Macro: String, Equatable, Sendable {
    case carbs, fat
}

/// A mood that isn't a filter in the Recipes tab.
nonisolated enum Craving: String, Sendable {
    case sweet, warm, spicy

    /// Words in a recipe's title or ingredients that fit the mood.
    var words: [String] {
        switch self {
        case .sweet: ["banana", "honey", "pancake", "oat", "yogurt", "berry", "berries", "fruit", "chocolate",
                      "peanut butter", "jam", "cinnamon", "sugar", "maple", "apple", "toast", "french toast", "smoothie"]
        case .warm: ["soup", "stew", "curry", "chili", "chilli", "pasta", "noodle", "ramen", "rice", "potato", "mac",
                     "porridge", "oatmeal", "risotto", "casserole", "bake", "hash", "dal", "chowder"]
        case .spicy: ["chili", "chilli", "hot sauce", "sriracha", "curry", "jalapeno", "salsa", "chili flakes",
                      "pepper flakes", "cayenne", "gochujang", "spicy", "harissa", "kimchi", "cajun", "peri"]
        }
    }

    var name: String { rawValue }
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
        let intent = intent(for: message)
        if case .aboutRecipe(let id) = intent { return aboutRecipe(id, asking: message, in: kitchen) }
        return answer(intent, in: kitchen)
    }

    // MARK: - Understanding

    func intent(for message: String) -> NutmegIntent {
        let text = " " + IngredientCatalog.key(for: message) + " "
        let words = text.split(separator: " ").map(String.init)

        if words.count <= 4, has(text, ["hi", "hello", "hey", "yo", "hiya", "morning", "evening"]) { return .greeting }
        if has(text, ["thank", "thanks", "thx", "cheers", "ty"]) { return .thanks }
        if has(text, ["help", "what can you do", "how do you work", "what do you do"]) { return .help }
        if has(text, ["who made you", "who created you", "who built you", "who is your creator", "who s your creator",
                      "whos your creator", "your creator", "who designed you", "who programmed you", "who owns you"]) {
            return .creator
        }
        if has(text, ["who are you", "what are you", "what s your name", "whats your name", "what is your name",
                      "your name"]) { return .aboutNutmeg }
        if has(text, ["my name", "who am i", "do you know me"]) { return .userName }

        // The shopping list before the pantry: "add milk to my list" is
        // something to buy, not something that's already in the kitchen.
        if let entries = Self.shoppingAdditions(in: message, text: text) { return .addToShoppingList(entries) }
        if has(text, ["shopping list", "my list", "on my list", "on the list", "what do i need to buy",
                      "what do i need to get", "what should i buy"]) { return .shoppingList }
        if has(text, ["running low", "run low", "almost out", "low on", "nearly out", "about to run out",
                      "running out"]) { return .runningLow }
        // Changing the pantry comes first: "add 2 cans of beans" isn't a
        // search for bean recipes.
        if let command = PantryCommand.parse(message) { return .pantryChange(command) }

        if let recipe = mentionedRecipe(in: text) { return .aboutRecipe(recipe) }

        if has(text, ["what did i eat", "what have i eaten", "what have i had", "what did i have", "what i ate",
                      "what i ve eaten", "today s meals", "meals today", "my meals", "food log", "eaten today",
                      "what i ve had"]) { return .eatenToday }

        // Numbers questions come before the money ones, so "calorie budget"
        // means calories, and before the ingredient rules, so "protein in
        // eggs" is a question about eggs, not a search for recipes.
        let nutritionWords = ["calorie", "calories", "calory", "kcal", "protein", "carb", "carbs", "fat", "macro", "macros"]
        if has(text, nutritionWords), let ingredient = mentionedIngredients(in: message).first {
            return .ingredientNutrition(ingredient)
        }
        if has(text, ["high protein", "high in protein", "rich in protein", "more protein", "protein rich", "protein packed",
                      "lots of protein", "a lot of protein", "protein heavy", "muscle", "gains", "gym", "workout",
                      "post workout"]) { return .highProtein }
        if has(text, ["low calorie", "low in calories", "low cal", "few calories", "fewer calories", "lower calorie",
                      "cutting", "lose weight", "weight loss", "lean", "slim"]) { return .lowCalorie }
        if has(text, ["hearty", "filling", "big meal", "bulk", "bulking", "gain weight", "high calorie", "calorie dense",
                      "more calories", "starving"]) { return .hearty }
        if has(text, ["carb", "carbs", "carbohydrate", "carbohydrates"]) { return .macroToday(.carbs) }
        if has(text, ["fat", "fats"]) { return .macroToday(.fat) }
        if has(text, ["protein"]) { return .proteinToday }
        if has(text, ["how much"]), has(text, ["eaten", "eat today", "ate today", "had today", "eaten today"]) {
            return .caloriesToday
        }
        if has(text, ["calorie", "calories", "calory", "kcal", "macro", "macros", "how much have i eaten",
                      "how much did i eat", "eaten today"]) { return .caloriesToday }
        if has(text, ["saved", "saving", "savings", "save money so far", "how much have i save"]) { return .savings }
        if has(text, ["streak"]) { return .streak }
        if has(text, ["cheap", "cheaper", "cheapest", "broke", "inexpensive", "low cost", "on a budget", "afford"]) { return .cheap }
        if has(text, ["budget", "spent", "spend", "spending"]) { return .budget }
        if has(text, ["what do i have", "what have i got", "what s in my", "whats in my", "in my pantry", "in my fridge",
                      "in my kitchen", "running low", "do i have", "left in"]) {
            let ingredients = mentionedIngredients(in: message)
            return ingredients.isEmpty ? .pantryContents : .withIngredients(ingredients)
        }

        if has(text, ["online", "internet", "the web", "new recipe", "new recipes", "something new", "something different",
                      "never made", "not made before"]) { return .onlineIdea }

        let ingredients = mentionedIngredients(in: message)
        if !ingredients.isEmpty { return .withIngredients(ingredients) }

        if has(text, ["surprise me", "surprise", "you pick", "you choose", "random"]) { return .surprise }
        if has(text, ["sweet", "sugary", "dessert", "treat"]) { return .craving(.sweet) }
        if has(text, ["spicy", "spice", "hot sauce", "kick"]) { return .craving(.spicy) }
        if has(text, ["warm", "warming", "cozy", "cosy", "comfort", "comforting", "hot meal"]) { return .craving(.warm) }

        if has(text, ["quick", "quicker", "fast", "faster", "hurry", "rush", "short on time", "no time", "minute", "min"]) { return .quick }
        if has(text, ["no stove", "without a stove", "microwave", "dorm", "no cooking", "no cook", "toaster", "kettle"]) {
            return .noStove
        }
        if has(text, ["healthy", "healthier", "light", "lighter", "veggie", "vegetable", "green", "nutritious", "fresh"]) {
            return .healthier
        }
        // Not sure what they want: ask, rather than guess.
        if has(text, ["what should i eat", "what should i cook", "what should i have", "what should i make", "hungry",
                      "any ideas", "no idea what", "don t know what", "dont know what", "help me decide",
                      "what to eat", "what to cook", "feed me", "can t decide", "cant decide", "not sure what"]) {
            return .moodQuestion
        }
        if has(text, ["what can i make", "what should i", "make", "cook", "dinner", "lunch", "breakfast", "hungry",
                      "eat", "recipe", "idea", "tonight", "craving", "food", "meal", "snack"]) {
            return .whatCanIMake
        }
        return fallback(message) ?? .offTopic
    }

    /// "Add milk to my shopping list", "I need to buy 6 eggs": the things
    /// to put on the list, with amounts. Nil unless it's about the list.
    static func shoppingAdditions(in message: String, text: String) -> [ShoppingEntry]? {
        let aboutList = ["shopping list", "my list", "the list", "to buy", "to get", "remind me to buy"]
        let wantsToAdd = ["add", "put", "need", "remind", "buy", "get", "stick"]
        func has(_ phrases: [String]) -> Bool {
            phrases.contains { text.contains(" " + IngredientCatalog.key(for: $0) + " ") }
        }
        guard has(aboutList), has(wantsToAdd), !message.contains("?") else { return nil }
        var cleaned = " " + message.lowercased() + " "
        for phrase in ["to my shopping list", "to the shopping list", "on my shopping list", "on the shopping list",
                       "onto my list", "to my list", "on my list", "to the list", "on the list", "shopping list",
                       "my list", "remind me to buy", "remind me to get", "i need to buy", "i need to get",
                       "need to buy", "need to get", "i have to buy", "please", "can you", "could you"] {
            cleaned = cleaned.replacingOccurrences(of: " " + phrase + " ", with: " ")
        }
        guard let lines = PantryCommand.parse("add " + cleaned)?.lines, !lines.isEmpty else { return nil }
        return lines.map { line in ShoppingEntry(item: line.item, amount: line.quantity.map { Amount($0, line.unit ?? .items) }) }
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
        case .highProtein:
            return all.filter { $0.recipe.nutrition.protein >= RecipeFilter.highProteinGrams }
                .sorted { $0.recipe.nutrition.protein > $1.recipe.nutrition.protein }
        case .lowCalorie:
            return all.filter { $0.recipe.nutrition.kcal <= RecipeFilter.lighterKcal }
                .sorted { $0.recipe.nutrition.kcal < $1.recipe.nutrition.kcal }
        case .hearty:
            return all.filter { $0.recipe.nutrition.kcal >= RecipeFilter.heartyKcal }
                .sorted { $0.recipe.nutrition.kcal > $1.recipe.nutrition.kcal }
        case .craving(let craving):
            return all.filter { match in
                let text = " " + IngredientCatalog.key(for: match.recipe.title + " "
                    + match.recipe.ingredients.map(\.amount).joined(separator: " ")) + " "
                return craving.words.contains { text.contains(" " + IngredientCatalog.key(for: $0)) }
            }
        case .onlineIdea:
            return all.filter(\.recipe.isOnline)
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
            return NutmegReply("I can find recipes from what you've got, tell you what's missing for one, and check your savings, streak, budget and calories. Try \"something quick\" or \"what can I make with eggs?\"")
        case .whatCanIMake:
            // Ideas for the meal it is now come first: breakfast in the morning.
            let forNow = kitchen.matches.filter { $0.recipe.suits(kitchen.slot) }
                + kitchen.matches.filter { !$0.recipe.suits(kitchen.slot) }
            return suggestions(from: forNow, in: kitchen,
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
        case .highProtein where kitchen.showsNutrition:
            return suggestions(from: candidates(for: .highProtein, in: kitchen), in: kitchen,
                               ready: "High-protein ones you can make right now:",
                               close: "Nothing high-protein is fully ready, but these are close:")
        case .lowCalorie where kitchen.showsNutrition:
            return suggestions(from: candidates(for: .lowCalorie, in: kitchen), in: kitchen,
                               ready: "Lighter-on-calories ones you can make right now:",
                               close: "Nothing light is fully ready, but these are close:")
        case .hearty where kitchen.showsNutrition:
            return suggestions(from: candidates(for: .hearty, in: kitchen), in: kitchen,
                               ready: "Filling ones you can make right now:",
                               close: "Nothing filling is fully ready, but these are close:")
        case .caloriesToday where kitchen.showsNutrition:
            return caloriesToday(kitchen)
        case .proteinToday where kitchen.showsNutrition:
            return proteinToday(kitchen)
        case .ingredientNutrition(let id) where kitchen.showsNutrition:
            return ingredientNutrition(id)
        case .macroToday(let macro) where kitchen.showsNutrition:
            return macroToday(macro, in: kitchen)
        case .highProtein, .lowCalorie, .hearty, .caloriesToday, .proteinToday, .ingredientNutrition, .macroToday:
            return NutmegReply("You've turned numbers off, so I'll keep it to cooking! You can turn calories and macros back on any time in Settings, under your goal.")
        case .eatenToday:
            return eatenToday(kitchen)
        case .pantryChange(let command):
            return pantryChange(command, in: kitchen)
        case .onlineIdea:
            return onlineIdea(kitchen)
        case .moodQuestion:
            return NutmegReply("Ooh, let's pick something! What are you in the mood for?",
                               quickReplies: Self.moods(for: kitchen))
        case .surprise:
            return surprise(kitchen)
        case .craving(let craving):
            let pool = candidates(for: .craving(craving), in: kitchen)
            guard !pool.isEmpty || kitchen.pantry.isEmpty else {
                return NutmegReply("Nothing \(craving.name) fits what you've got right now. Want to hear what you can make?",
                                   quickReplies: ["What can I make?", "Surprise me"])
            }
            return suggestions(from: pool, in: kitchen,
                               ready: "Something \(craving.name) you can make right now:",
                               close: "Nothing \(craving.name) is fully ready, but these are close:")
        case .withIngredients(let ids):
            return withIngredients(ids, in: kitchen)
        case .aboutRecipe(let id):
            return aboutRecipe(id, in: kitchen)
        case .pantryContents:
            var reply = pantryContents(kitchen)
            reply.topic = .pantry
            return reply
        case .savings:
            return savings(kitchen)
        case .streak:
            return streak(kitchen)
        case .budget:
            return budget(kitchen)
        case .shoppingList:
            var reply = shoppingList(kitchen)
            reply.topic = .shoppingList
            return reply
        case .addToShoppingList(let entries):
            return NutmegReply("Done! I've put \(Self.list(entries.map(Self.named))) on your shopping list.",
                               listAdditions: entries)
        case .runningLow:
            return runningLow(kitchen)
        case .creator:
            return NutmegReply("Joshua made me! He's a high school student who built Larder so students can eat well on a tight budget. I'm here to help you cook.",
                               quickReplies: ["What can I make?", "Surprise me"])
        case .aboutNutmeg:
            return NutmegReply("I'm Nutmeg, Larder's kitchen helper! I know what's in your pantry, which recipes you can make, and how your week's going.",
                               quickReplies: ["What can I make?", "What's in my pantry?"])
        case .userName:
            return NutmegReply("I don't know your name! Larder doesn't have accounts, so I only know your kitchen. What should we cook?",
                               quickReplies: ["What can I make?", "Surprise me"])
        case .offTopic:
            return NutmegReply("I'm best with food things: what to cook, what's in your pantry, and how your week's going. Want some ideas?",
                               quickReplies: ["What can I make?", "Surprise me", "What's in my pantry?"],
                               offer: .ideas)
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
            return NutmegReply(text, recipeIDs: ready.map(\.recipe.id),
                               quickReplies: ready.count > NutmegReply.maxRecipes ? ["Show me more"] : [],
                               pool: ready.map(\.recipe.id))
        }
        let close = pool.filter { $0.missing.count <= 2 }.sorted { $0.missing.count < $1.missing.count }
        guard let best = close.first else {
            // Nothing's near: still show the closest, and offer to put what the
            // best one needs on the list, rather than a dead end.
            let nearest = pool.sorted { $0.missing.count < $1.missing.count }
            guard let first = nearest.first else {
                return NutmegReply("I couldn't find anything like that yet. Want to hear what you can make?",
                                   quickReplies: ["What can I make?", "Surprise me"], offer: .ideas)
            }
            let needs = first.missing.compactMap { line in
                IngredientCatalog.resolvedItem(forID: line.id).map { ShoppingEntry(item: $0, amount: ShoppingAmount.amount(for: line)) }
            }
            return NutmegReply("Nothing's ready with what you've got yet. The closest is \(first.recipe.title), which needs \(Self.list(names(first.missing))). Want me to put that on your shopping list?",
                               recipeIDs: nearest.map(\.recipe.id),
                               quickReplies: ["Yes, add it to my list", "Show me more", "Surprise me"],
                               offer: needs.isEmpty ? nil : .addToList(needs), pool: nearest.map(\.recipe.id))
        }
        let needs = best.missing.compactMap { line in
            IngredientCatalog.resolvedItem(forID: line.id).map { ShoppingEntry(item: $0, amount: ShoppingAmount.amount(for: line)) }
        }
        return NutmegReply("\(closeLine) \(best.recipe.title) only needs \(Self.list(names(best.missing))). Want me to put that on your shopping list?",
                           recipeIDs: close.map(\.recipe.id),
                           quickReplies: needs.isEmpty ? [] : ["Yes, add it to my list", "Show me more"],
                           offer: needs.isEmpty ? nil : .addToList(needs), pool: close.map(\.recipe.id))
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

    /// A question about one recipe, answered for what it actually asks:
    /// how long it takes, what it costs, its numbers, or what's missing.
    func aboutRecipe(_ id: String, asking message: String, in kitchen: KitchenSnapshot) -> NutmegReply {
        guard let recipe = kitchen.match(for: id)?.recipe ?? RecipeStore.recipe(withID: id) else {
            return answer(.whatCanIMake, in: kitchen)
        }
        let text = " " + IngredientCatalog.key(for: message) + " "
        let missing = kitchen.match(for: id).map { $0.isReady ? " You've got everything for it." : " You'd need \(Self.list(names($0.missing)))." } ?? ""
        if has(text, ["how long", "long", "time", "minutes", "take", "quick"]) {
            return NutmegReply("\(recipe.title) takes about \(recipe.minutes) minutes.\(missing)", recipeIDs: [id])
        }
        if has(text, ["cost", "price", "how much is", "how much does", "expensive", "cheap"]) {
            return NutmegReply("\(recipe.title) comes to about \(recipe.costText) a serving.\(missing)", recipeIDs: [id])
        }
        if kitchen.showsNutrition, has(text, ["calorie", "calories", "kcal", "protein", "carb", "carbs", "fat", "macro", "macros", "healthy"]) {
            let n = recipe.nutrition
            return NutmegReply("\(recipe.title) is about \(n.roundedKcal) kcal a serving, with \(n.roundedProtein) g protein, \(n.roundedCarbs) g carbs and \(n.roundedFat) g fat.", recipeIDs: [id])
        }
        if has(text, ["how many", "serves", "servings", "people"]) {
            let serves = recipe.servings == 1 ? "1 person" : "\(recipe.servings) people"
            return NutmegReply("\(recipe.title) serves \(serves).\(missing)", recipeIDs: [id])
        }
        return aboutRecipe(id, in: kitchen)
    }

    private func aboutRecipe(_ id: String, in kitchen: KitchenSnapshot) -> NutmegReply {
        guard let recipe = kitchen.match(for: id)?.recipe ?? RecipeStore.recipe(withID: id) else {
            return answer(.whatCanIMake, in: kitchen)
        }
        guard let match = kitchen.match(for: id) else {
            return NutmegReply("\(recipe.title) doesn't fit what you eat, so I've left it out. Want something similar?")
        }
        let numbers = kitchen.showsNutrition
            ? " It's about \(recipe.nutrition.roundedKcal) kcal and \(recipe.nutrition.roundedProtein) g protein a serving."
            : ""
        if match.isReady {
            return NutmegReply("You've got everything for \(recipe.title)! It's about \(recipe.minutes) minutes and \(recipe.costText) a serving.\(numbers)",
                               recipeIDs: [id])
        }
        return NutmegReply("For \(recipe.title) you're missing \(Self.list(names(match.missing))). Everything else is already in your kitchen.\(numbers)",
                           recipeIDs: [id])
    }

    // MARK: - Shopping list and running low

    /// "How much of each?" after listing the shopping list or the pantry.
    func amounts(for topic: NutmegReply.ReplyTopic, in kitchen: KitchenSnapshot) -> NutmegReply {
        let lines: [(name: String, amount: String?)]
        switch topic {
        case .shoppingList:
            lines = kitchen.shopping.filter { !$0.isBought }.map { ($0.name.lowercased(), $0.amount) }
        case .pantry:
            lines = kitchen.pantry.map { ($0.name.lowercased(), $0.amount) }
        }
        guard !lines.isEmpty else { return NutmegReply("There's nothing there right now.") }
        let known = lines.filter { $0.amount != nil }.map { "\($0.name): \($0.amount!)" }
        let unknown = lines.filter { $0.amount == nil }.map(\.name)
        let place = topic == .shoppingList ? "your list" : "your pantry"
        guard !known.isEmpty else {
            return NutmegReply("You haven't set amounts for anything on \(place) yet. Tap an item there to add one, or tell me, like \"2 cans of beans\".")
        }
        var text = "Here's what I know: \(known.joined(separator: ", "))."
        if !unknown.isEmpty { text += " No amount set for \(Self.list(unknown))." }
        return NutmegReply(text)
    }

    private func shoppingList(_ kitchen: KitchenSnapshot) -> NutmegReply {
        let toGet = kitchen.shopping.filter { !$0.isBought }
        let bought = kitchen.shopping.count - toGet.count
        guard !toGet.isEmpty else {
            let basket = bought > 0 ? " Everything's in your basket already." : ""
            return NutmegReply("Nothing left to get.\(basket) Tell me what to add, like \"add milk to my list\".")
        }
        let items = toGet.prefix(8).map { line in line.amount.map { "\(line.name.lowercased()) (\($0))" } ?? line.name.lowercased() }
        let more = toGet.count > items.count ? ", and \(toGet.count - items.count) more" : ""
        let basket = bought > 0 ? " \(bought) already in your basket." : ""
        return NutmegReply("On your list: \(items.joined(separator: ", "))\(more).\(basket)")
    }

    private func runningLow(_ kitchen: KitchenSnapshot) -> NutmegReply {
        let low = kitchen.lowItems
        guard !low.isEmpty else {
            return NutmegReply("Nothing looks low to me. If you add amounts in your pantry, I can keep a better eye on it.")
        }
        let listed = Set(kitchen.shopping.filter { !$0.isBought }.map { $0.name.lowercased() })
        let names = low.map { item in item.amount.map { "\(item.name.lowercased()) (\($0))" } ?? item.name.lowercased() }
        let toAdd = low.filter { !listed.contains($0.name.lowercased()) }
            .compactMap { IngredientCatalog.resolvedItem(forID: $0.id).map { ShoppingEntry(item: $0) } }
        guard !toAdd.isEmpty else {
            return NutmegReply("You're running low on \(Self.list(names)). They're already on your shopping list.")
        }
        let addNames = Self.list(toAdd.map { $0.item.name.lowercased() })
        // When some are already on the list, say which ones still need adding.
        let already = low.count - toAdd.count
        let ask = already > 0
            ? "\(already == 1 ? "One's" : "Some are") already on your shopping list. Want me to add \(addNames) too?"
            : "Want me to add \(toAdd.count == 1 ? "it" : "them") to your shopping list?"
        return NutmegReply("You're running low on \(Self.list(names)). \(ask)",
                           quickReplies: ["Yes, add \(toAdd.count == 1 ? "it" : "them")", "No thanks"],
                           offer: .addToList(toAdd))
    }

    /// "eggs (6)" or "milk".
    static func named(_ entry: ShoppingEntry) -> String {
        let name = entry.item.name.lowercased()
        return entry.amount.map { "\(name) (\($0.text))" } ?? name
    }

    // MARK: - Follow-ups

    /// Saying yes to what Nutmeg offered.
    func accept(_ offer: FollowUp, in kitchen: KitchenSnapshot) -> NutmegReply {
        switch offer {
        case .addToList(let entries):
            return NutmegReply("Done! \(Self.list(entries.map(Self.named)).capitalizedFirstLetter) \(entries.count == 1 ? "is" : "are") on your shopping list.",
                               listAdditions: entries)
        case .ideas:
            return answer(.whatCanIMake, in: kitchen)
        }
    }

    // MARK: - Moods, surprises and online ideas

    /// The quick replies to "what are you in the mood for?". Numbers-based
    /// ones only when numbers are on, and online only when it can answer.
    static func moods(for kitchen: KitchenSnapshot) -> [String] {
        var moods = ["Something quick"]
        if kitchen.showsNutrition { moods.append("Something filling") }
        moods += ["Something light", "Something warm", "Something sweet", "Something spicy", "Something cheap"]
        if kitchen.online == .ready, kitchen.matches.contains(where: \.recipe.isOnline) {
            moods.append("Something new from online")
        }
        moods.append("Surprise me")
        return moods
    }

    /// A random pick, skipping the ones already suggested, so "surprise me
    /// again" really is something new (until they've all come up).
    func surprise(_ kitchen: KitchenSnapshot, avoiding shown: Set<String> = []) -> NutmegReply {
        if kitchen.pantry.isEmpty { return answer(.whatCanIMake, in: kitchen) }
        let ready = kitchen.readyMatches
        let close = kitchen.matches.filter { !$0.isReady && $0.missing.count <= 1 }
        let everything = ready + close
        let fresh = everything.filter { !shown.contains($0.recipe.id) }
        let pool = fresh.isEmpty ? everything : fresh
        guard let pick = (pool.filter(\.isReady).randomElement() ?? pool.randomElement()) else {
            return answer(.whatCanIMake, in: kitchen)
        }
        let text = pick.isReady
            ? "Ta-da! How about \(pick.recipe.title)? You've got everything for it."
            : "How about \(pick.recipe.title)? You'd just need \(Self.list(names(pick.missing)))."
        return NutmegReply(text, recipeIDs: [pick.recipe.id], quickReplies: ["Surprise me again"])
    }

    private func onlineIdea(_ kitchen: KitchenSnapshot) -> NutmegReply {
        let online = candidates(for: .onlineIdea, in: kitchen)
        if kitchen.online == .ready, !online.isEmpty {
            let ready = online.filter(\.isReady)
            let picks = ready.isEmpty ? online.sorted { $0.missing.count < $1.missing.count } : ready
            let intro = ready.isEmpty
                ? "Here's something new I found online. You'd need a thing or two for these:"
                : "Here's something new I found online that you can make right now:"
            return NutmegReply(intro, recipeIDs: picks.map(\.recipe.id))
        }
        let why: String
        switch kitchen.online {
        case .off: why = "Online recipes are switched off. You can turn them on in Settings, under Online recipes."
        case .resting: why = "I've used up today's online lookups."
        case .offline: why = "I can't reach the online recipes right now."
        case .looking: why = "I'm still looking online."
        case .ready: why = "I couldn't find anything new online for this pantry yet."
        case .unavailable: why = "I only have Larder's own recipes here."
        }
        let own = kitchen.readyMatches.filter { !$0.recipe.isOnline }
        guard !own.isEmpty else { return NutmegReply(why) }
        return NutmegReply(why + " Here are some of Larder's own you can make:", recipeIDs: own.map(\.recipe.id))
    }

    // MARK: - Changing the pantry

    /// Shows what would change as a card to confirm. Taking something off
    /// that isn't there is left out, with a word about it.
    private func pantryChange(_ command: PantryCommand, in kitchen: KitchenSnapshot) -> NutmegReply {
        let have = kitchen.pantryIDs
        let notThere = command.lines.filter { $0.action == .remove && !have.contains($0.item.id) }
        var kept = command
        kept.lines.removeAll { $0.action == .remove && !have.contains($0.item.id) }
        let missingNote = notThere.isEmpty ? ""
            : " \(Self.list(notThere.map(\.item.name))) \(notThere.count == 1 ? "isn't" : "aren't") in your pantry, so there's nothing to take off."
        guard !kept.lines.isEmpty else {
            return NutmegReply(missingNote.trimmingCharacters(in: .whitespaces))
        }
        let intro: String
        if kept.lines.allSatisfy({ $0.action == .add }) {
            intro = "Got it! Here's what I'll add. Change the amounts if you need to."
        } else if kept.lines.allSatisfy({ $0.action == .remove }) {
            intro = "Oh no, all gone? I'll take these off your pantry."
        } else {
            intro = "Here's what I'll change in your pantry."
        }
        return NutmegReply(intro + missingNote, pantryChange: kept)
    }

    // MARK: - Calories and macros

    private func eatenToday(_ kitchen: KitchenSnapshot) -> NutmegReply {
        let meals = kitchen.mealsTodayList
        guard !meals.isEmpty else {
            return NutmegReply("Nothing cooked in Larder yet today. Want an idea for your next meal?",
                               quickReplies: ["What can I make?", "Surprise me"])
        }
        let listed = meals.map { meal -> String in
            let time = meal.time.formatted(date: .omitted, time: .shortened)
            let kcal = kitchen.showsNutrition ? meal.macros.map { ", about \($0.roundedKcal.formatted()) kcal" } ?? "" : ""
            return "\(meal.title.lowercased()) (\(time)\(kcal))"
        }
        var text = "Today you've cooked \(Self.list(listed))."
        guard kitchen.showsNutrition else { return NutmegReply(text + " Nice work!") }
        let today = kitchen.today
        text += " Together that's about \(today.roundedKcal.formatted()) kcal, \(today.roundedProtein) g protein, \(today.roundedCarbs) g carbs and \(today.roundedFat) g fat."
        if let targets = kitchen.targets { text += Self.left(of: targets, after: today) }
        return NutmegReply(text + " That's only meals cooked here, not everything you ate.")
    }

    /// " Left for today: about …", naming only what's still to go.
    static func left(of targets: DailyTargets, after today: Macros) -> String {
        var parts: [String] = []
        let kcal = targets.kcal - today.roundedKcal
        if kcal > 0 { parts.append("\(kcal.formatted()) kcal") }
        for (name, target, had) in [("protein", targets.protein, today.roundedProtein),
                                    ("carbs", targets.carbs, today.roundedCarbs), ("fat", targets.fat, today.roundedFat)]
        where target - had > 0 {
            parts.append("\(target - had) g \(name)")
        }
        return parts.isEmpty ? " That's your targets for today reached." : " Left for today: about \(list(parts))."
    }

    private func caloriesToday(_ kitchen: KitchenSnapshot) -> NutmegReply {
        let target = kitchen.targets.map { " Your target for the day is about \($0.kcal.formatted()) kcal." } ?? ""
        guard kitchen.mealsToday > 0 else {
            return NutmegReply("Nothing cooked in Larder yet today, so nothing to add up.\(target)")
        }
        let today = kitchen.today
        let meals = kitchen.mealsToday == 1 ? "1 meal" : "\(kitchen.mealsToday) meals"
        var text = "So far today you've cooked \(meals): about \(today.roundedKcal.formatted()) kcal, \(today.roundedProtein) g protein, \(today.roundedCarbs) g carbs and \(today.roundedFat) g fat."
        if let targets = kitchen.targets {
            let left = targets.kcal - today.roundedKcal
            text += left > 0
                ? " Your target is about \(targets.kcal.formatted()) kcal, so there's about \(left.formatted()) to go."
                : " Your target is about \(targets.kcal.formatted()) kcal."
            let macrosLeft = [("protein", targets.protein - today.roundedProtein),
                              ("carbs", targets.carbs - today.roundedCarbs), ("fat", targets.fat - today.roundedFat)]
                .filter { $0.1 > 0 }.map { "\($0.1) g \($0.0)" }
            if !macrosLeft.isEmpty { text += " Still to go: about \(Self.list(macrosLeft))." }
        }
        return NutmegReply(text + " That's only meals cooked here, not everything you ate.")
    }

    private func proteinToday(_ kitchen: KitchenSnapshot) -> NutmegReply {
        let protein = kitchen.today.roundedProtein
        guard kitchen.mealsToday > 0 else {
            let target = kitchen.targets.map { " Your target is about \($0.protein) g a day." } ?? ""
            let ideas = candidates(for: .highProtein, in: kitchen).filter(\.isReady).map(\.recipe.id)
            return NutmegReply("Nothing cooked in Larder yet today.\(target)\(ideas.isEmpty ? "" : " Here are some high-protein ideas:")",
                               recipeIDs: ideas)
        }
        guard let targets = kitchen.targets else {
            return NutmegReply("About \(protein) g protein from what you've cooked in Larder today.")
        }
        let left = targets.protein - protein
        if left > 10 {
            let ideas = candidates(for: .highProtein, in: kitchen).filter(\.isReady).map(\.recipe.id)
            return NutmegReply("About \(protein) g protein so far today, out of about \(targets.protein) g. Here's something to help:",
                               recipeIDs: ideas)
        }
        return NutmegReply("About \(protein) g protein so far today, out of about \(targets.protein) g. Nicely done!")
    }

    private func macroToday(_ macro: Macro, in kitchen: KitchenSnapshot) -> NutmegReply {
        let name = macro.rawValue
        let target = kitchen.targets.map { macro == .carbs ? $0.carbs : $0.fat }
        guard kitchen.mealsToday > 0 else {
            let aim = target.map { " Your target is about \($0) g of \(name) a day." } ?? ""
            return NutmegReply("Nothing cooked in Larder yet today, so no \(name) to add up.\(aim)")
        }
        let had = macro == .carbs ? kitchen.today.roundedCarbs : kitchen.today.roundedFat
        guard let target else {
            return NutmegReply("About \(had) g \(name) from what you've cooked in Larder today.")
        }
        let left = target - had
        let tail = left > 0 ? "about \(left) g to go." : "that's your target reached."
        return NutmegReply("About \(had) g \(name) so far today, out of about \(target) g, so \(tail) That's only meals cooked here.")
    }

    private func ingredientNutrition(_ id: String) -> NutmegReply {
        let name = IngredientCatalog.ingredient(withID: id)?.name ?? id
        guard let entry = NutritionTable.entry(for: id) else {
            return NutmegReply("I don't have numbers for \(name.lowercased()) yet.")
        }
        let f = { (value: Double) in value.formatted(.number.precision(.fractionLength(0...1))) }
        return NutmegReply("\(name), per 100 g: about \(f(entry.kcal)) kcal, \(f(entry.protein)) g protein, \(f(entry.carbs)) g carbs and \(f(entry.fat)) g fat (USDA FoodData Central).")
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
        (.highProtein, "I need more protein"),
        (.lowCalorie, "something low in calories"),
        (.caloriesToday, "how am I doing on calories"),
        (.proteinToday, "how much protein did I get"),
        (.eatenToday, "what have I eaten so far today"),
        (.moodQuestion, "I don't know what I want to eat"),
    ]

    static func closest(_ message: String) -> NutmegIntent? {
        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else { return nil }
        let scored = examples.map { ($0.0, embedding.distance(between: message.lowercased(), and: $0.1)) }
        guard let best = scored.min(by: { $0.1 < $1.1 }), best.1 < threshold else { return nil }
        return best.0
    }
}

nonisolated extension String {
    /// "eggs and milk" → "Eggs and milk".
    var capitalizedFirstLetter: String { prefix(1).uppercased() + dropFirst() }
}
