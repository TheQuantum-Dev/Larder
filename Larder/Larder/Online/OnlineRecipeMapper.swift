//
//  OnlineRecipeMapper.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation

/// Matches a recipe's ingredient lines to the app's own ingredients. It is
/// careful in one direction on purpose: it would rather say "you're missing
/// this" about something the person has than say "you have everything" when
/// they don't, so a name only matches when it clearly is that ingredient.
nonisolated enum OnlineIngredientMapper {
    /// Words that describe how something is prepared, or how big or what colour
    /// it is, without changing what it is.
    static let modifiers: Set<String> = [
        "fresh", "large", "small", "medium", "big", "ripe", "boneless", "skinless", "bone", "in", "skin", "on",
        "lean", "extra", "virgin", "chopped", "diced", "minced", "sliced", "shredded", "grated", "cooked", "raw",
        "frozen", "canned", "organic", "whole", "unsalted", "salted", "plain", "red", "green", "yellow", "orange",
        "white", "purple", "ground", "warm", "hot", "cold", "boiling", "ice", "finely", "roughly", "freshly",
        "thinly", "packed", "torn", "baby", "flat", "leaf",
    ]

    /// Words that do change what something is, so "coconut milk" is never milk
    /// and "cauliflower rice" never rice.
    static let identityChangers: Set<String> = [
        "coconut", "cauliflower", "almond", "oat", "soy", "peanut", "cashew", "hazelnut", "cocoa", "sesame",
        "fish", "cream",
    ]

    /// A trailing count word: "2 cloves garlic" is garlic.
    static let unitNouns: Set<String> = [
        "clove", "stalk", "sprig", "head", "bunch", "floret", "slice", "fillet", "wedge", "cube", "can",
        "piece", "strip", "link", "leaf", "ear", "rib",
    ]

    /// The last word of a seasoning: paprika, garlic powder, red pepper flakes.
    static let seasoningHeads: Set<String> = [
        "powder", "flake", "seasoning", "spice", "masala", "paprika", "cumin", "oregano", "turmeric", "cinnamon",
        "cayenne", "cardamom", "coriander", "nutmeg", "allspice", "saffron", "extract", "essence", "soda",
    ]

    /// Common recipe names the catalog doesn't list, by their cleaned-up form.
    static let synonyms: [String: String] = [
        "egg white": "egg", "egg yolk": "egg", "all purpose flour": "flour", "bread flour": "flour",
        "chicken broth": "broth", "chicken stock": "broth", "vegetable broth": "broth", "vegetable stock": "broth",
        "beef broth": "broth", "beef stock": "broth", "lemon juice": "lemon", "lime juice": "lime",
        "pepper": "black-pepper", "kosher salt": "salt", "sea salt": "salt", "bay leaf": "black-pepper",
    ]

    /// Whose result is safe to guess from the last word alone, like "goat
    /// cheese" or "flat leaf parsley".
    static let safeHeads: Set<String> = [
        "herbs", "cheese", "onion", "tomato", "mushroom", "lettuce", "spinach", "kale", "cabbage", "carrot",
        "celery", "cucumber", "zucchini", "apple", "banana", "lemon", "lime", "orange", "avocado", "broccoli",
        "corn", "peas", "potato", "garlic", "ginger", "rice", "beans", "strawberry", "blueberry",
    ]

    /// The id to use for one ingredient line: a catalog id when it clearly is
    /// one, the seasoning stand-in for spices, or a `custom:` id otherwise.
    static func id(forName name: String) -> String {
        let key = IngredientCatalog.key(for: name)
        guard !key.isEmpty else { return IngredientCatalog.customPrefix + "ingredient" }
        var words = key.split(separator: " ").map(String.init)

        // Recipe wording first: a bare "pepper" here is black pepper, though the
        // catalog lists it as a bell pepper for pantry scans.
        if let synonym = synonyms[key] { return synonym }
        if let hit = IngredientCatalog.exactID(for: key) { return hit }
        if let last = words.last, seasoningHeads.contains(last) { return "black-pepper" }

        // Drop the words that only describe it, then try again.
        let core = words.filter { !modifiers.contains($0) }
        if !core.isEmpty, core != words {
            let joined = core.joined(separator: " ")
            if let hit = IngredientCatalog.exactID(for: joined) ?? synonyms[joined] { return hit }
            words = core
        }

        // "salmon fillet" is salmon.
        if words.count > 1, let last = words.last, unitNouns.contains(last) {
            let joined = words.dropLast().joined(separator: " ")
            if let hit = IngredientCatalog.exactID(for: joined) { return hit }
        }

        // A short name ending in something like "cheese" or "parsley" is that.
        if words.count <= 3, let last = words.last, words.dropLast().allSatisfy({ !identityChangers.contains($0) }),
           let hit = IngredientCatalog.exactID(for: last), safeHeads.contains(hit) {
            return hit
        }

        return IngredientCatalog.customPrefix + words.joined(separator: " ")
    }

    static func line(for dto: OnlineIngredientDTO) -> RecipeIngredient? {
        let name = dto.nameClean ?? dto.name ?? ""
        guard !IngredientCatalog.key(for: name).isEmpty else { return nil }
        let amount = dto.original ?? [dto.amount.map { $0.formatted() }, dto.unit, dto.name]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        return RecipeIngredient(id: id(forName: name), amount: amount, qty: 0, optional: nil, alt: nil)
    }
}

/// Turns a recipe from online into the app's own `Recipe`, so everything else
/// (matching, Cook Mode, calories, sharing) works on it without knowing where it came from.
nonisolated enum OnlineRecipeMapper {
    static let idPrefix = "sp-"

    static let safetyStep = "Food safety: cook meat, poultry and fish all the way through (chicken and turkey to "
        + "165°F / 74°C, ground meat to 160°F / 71°C, pork and fish to 145°F / 63°C) and cook eggs until they're firm."

    /// Words that mean pork or alcohol, which the service's own labels don't cover.
    static let porkWords: Set<String> = ["pork", "bacon", "ham", "prosciutto", "pancetta", "lard", "sausage",
                                         "chorizo", "salami", "pepperoni", "gammon"]
    static let alcoholWords: Set<String> = ["wine", "beer", "rum", "vodka", "whiskey", "whisky", "bourbon", "brandy",
                                            "gin", "tequila", "liqueur", "sake", "sherry", "champagne", "cognac",
                                            "vermouth", "ale", "stout"]
    static let nutWords: Set<String> = ["peanut", "almond", "walnut", "cashew", "pecan", "pistachio", "hazelnut",
                                        "macadamia", "nut"]

    /// Nil when the recipe is missing something Cook Mode or the numbers need.
    static func recipe(from dto: OnlineRecipeDTO) -> Recipe? {
        let title = dto.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        let rawSteps = (dto.analyzedInstructions ?? []).flatMap { $0.steps ?? [] }
        var steps = rawSteps.compactMap { step -> RecipeStep? in
            let text = step.step.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : RecipeStep(text: text, timer: seconds(from: step.length))
        }
        let lines = (dto.extendedIngredients ?? []).compactMap(OnlineIngredientMapper.line(for:))
        guard !steps.isEmpty, !lines.isEmpty, let nutrition = macros(from: dto.nutrition) else { return nil }

        let flagged = traits(for: dto, title: title, lines: lines)
        let fromIngredients = lines.compactMap { IngredientCatalog.ingredient(withID: $0.id)?.traits }
            .reduce(DietTraits(), { $0.union($1) })
        // The steps come from someone else's kitchen, so add the safe temperatures
        // when there's meat, fish or egg in it (the diet flags alone don't say).
        if dto.vegetarian == false || !fromIngredients.isDisjoint(with: [.meat, .fish, .egg]) {
            steps.append(RecipeStep(text: safetyStep, timer: nil))
        }

        return Recipe(id: idPrefix + String(dto.id), title: title, emoji: emoji(for: dto, lines: lines),
                      minutes: max(dto.readyInMinutes ?? 30, 1), servings: max(dto.servings ?? 1, 1),
                      equipment: equipment(from: rawSteps, text: steps.map(\.text).joined(separator: " ")),
                      ingredients: lines, steps: steps,
                      tip: "I found this one online, so give the steps a quick read before you start.",
                      healthy: dto.veryHealthy ?? false, meals: meals(from: dto.dishTypes ?? []),
                      imageURL: dto.image,
                      source: RecipeSource(name: sourceName(for: dto), url: dto.sourceUrl, credit: dto.creditsText),
                      costOverride: dto.pricePerServing.map { max($0 / 100, 0.25) } ?? 2.5,
                      nutritionOverride: nutrition, traitsOverride: flagged)
    }

    // MARK: - Pieces

    static func seconds(from length: OnlineLengthDTO?) -> Int? {
        guard let number = length?.number, number > 0, let unit = length?.unit?.lowercased() else { return nil }
        let seconds: Double
        switch unit {
        case "minutes", "minute", "min", "mins": seconds = number * 60
        case "hours", "hour", "hr", "hrs": seconds = number * 3_600
        case "seconds", "second", "sec", "secs": seconds = number
        default: return nil
        }
        // Cook Mode's timers run from ten seconds to three hours.
        return min(max(Int(seconds.rounded()), 10), 10_800)
    }

    static func macros(from nutrition: OnlineNutritionDTO?) -> Macros? {
        let nutrients = nutrition?.nutrients ?? []
        func amount(_ name: String) -> Double? {
            nutrients.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.amount
        }
        guard let kcal = amount("Calories"), kcal > 0 else { return nil }
        return Macros(kcal: kcal, protein: amount("Protein") ?? 0, carbs: amount("Carbohydrates") ?? 0,
                      fat: amount("Fat") ?? 0)
    }

    static func meals(from dishTypes: [String]) -> [String]? {
        let types = Set(dishTypes.map { $0.lowercased() })
        func has(_ names: [String]) -> Bool { names.contains { types.contains($0) } }
        var meals = Set<String>()
        if has(["breakfast", "morning meal", "brunch"]) { meals.insert(MealSlot.breakfast.rawValue) }
        if has(["lunch", "salad", "soup", "sandwich", "brunch"]) { meals.insert(MealSlot.lunch.rawValue) }
        if has(["dinner", "main course", "main dish"]) {
            meals.insert(MealSlot.lunch.rawValue)
            meals.insert(MealSlot.dinner.rawValue)
        }
        guard !meals.isEmpty else { return nil }
        return MealSlot.allCases.map(\.rawValue).filter(meals.contains)
    }

    /// From the equipment each step names, or, if it names none the app has,
    /// from what the steps say they're doing.
    static func equipment(from steps: [OnlineStepDTO], text: String) -> [Equipment] {
        var found = Set<Equipment>()
        for name in steps.flatMap({ $0.equipment ?? [] }).compactMap(\.name) {
            let name = name.lowercased()
            func mentions(_ words: [String]) -> Bool { words.contains { name.contains($0) } }
            if mentions(["microwave"]) { found.insert(.microwave) }
            else if mentions(["kettle"]) { found.insert(.kettle) }
            else if mentions(["toaster"]) { found.insert(.toaster) }
            else if mentions(["pot", "saucepan", "stockpot", "dutch oven"]) { found.insert(.pot) }
            else if mentions(["pan", "skillet", "wok", "griddle"]) { found.insert(.pan) }
            else if mentions(["oven", "baking", "roasting"]) { found.insert(.oven) }
        }
        if found.isEmpty {
            let text = text.lowercased()
            if text.contains("microwave") { found.insert(.microwave) }
            if text.contains("oven") || text.contains("bake") || text.contains("roast") { found.insert(.oven) }
            if text.contains("boil") || text.contains("simmer") { found.insert(.pot) }
            if ["fry", "saute", "sauté", "skillet", "sear"].contains(where: { text.contains($0) }) { found.insert(.pan) }
        }
        return Equipment.allCases.filter(found.contains)
    }

    static func emoji(for dto: OnlineRecipeDTO, lines: [RecipeIngredient]) -> String {
        let types = Set((dto.dishTypes ?? []).map { $0.lowercased() })
        if !types.isDisjoint(with: ["breakfast", "morning meal", "brunch"]) { return "🍳" }
        if types.contains("soup") { return "🍲" }
        if types.contains("salad") { return "🥗" }
        if !types.isDisjoint(with: ["sandwich", "burger"]) { return "🥪" }
        let protein = lines.compactMap { IngredientCatalog.ingredient(withID: $0.id) }.first { $0.category == .protein }
        return protein?.emoji ?? "🍽️"
    }

    static func sourceName(for dto: OnlineRecipeDTO) -> String {
        if let name = dto.sourceName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty { return name }
        if let host = dto.sourceUrl.flatMap(URL.init(string:))?.host {
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
        return "the web"
    }

    /// What a diet could object to. The service's labels come first; anything
    /// they don't cover is caught by looking for the words themselves. It's set
    /// so a recipe is left out when in doubt.
    static func traits(for dto: OnlineRecipeDTO, title: String, lines: [RecipeIngredient]) -> DietTraits {
        var traits: DietTraits = []
        if dto.vegetarian == false { traits.insert(.meat) }
        if dto.vegan == false { traits.formUnion([.egg, .honey]) }
        if dto.dairyFree == false { traits.insert(.dairy) }
        if dto.glutenFree == false { traits.insert(.gluten) }

        let words = Set(([title] + lines.map(\.amount))
            .flatMap { IngredientCatalog.key(for: $0).split(separator: " ").map(String.init) })
        if !words.isDisjoint(with: porkWords) { traits.formUnion([.pork, .meat]) }
        if !words.isDisjoint(with: alcoholWords) { traits.insert(.alcohol) }
        if !words.isDisjoint(with: nutWords) { traits.insert(.nuts) }
        return traits
    }
}
