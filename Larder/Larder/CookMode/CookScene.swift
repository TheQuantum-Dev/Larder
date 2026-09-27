//
//  CookScene.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation

/// What Nutmeg is up to in the little kitchen above a Cook Mode step: stirring
/// a pot, frying, chopping, and so on. Worked out from the step's own words,
/// with the recipe's equipment as a tiebreak, so online recipes get scenes too.
nonisolated enum CookScene: String, CaseIterable, Sendable {
    case boil, fry, oven, microwave, kettle, toast, chop, mix, serve, check, chill, prep

    /// Picks the scene for step `index` of `recipe`.
    static func `for`(step index: Int, in recipe: Recipe) -> CookScene {
        guard recipe.steps.indices.contains(index) else { return .prep }
        let step = recipe.steps[index]
        let text = step.text.lowercased()
        let words = Set(text.split { !$0.isLetter }.map(String.init))

        func has(_ stems: [String]) -> Bool {
            stems.contains { stem in
                stem.contains(" ") ? text.contains(stem) : words.contains { $0.hasPrefix(stem) }
            }
        }

        // A temperature check is the food-safety step.
        if text.contains("°") || has(["thermometer"]) { return .check }
        if has(["microwav"]) { return .microwave }
        // Hot water comes from the kettle, unless the recipe boils it in a pot.
        if has(["kettle"]) || (has(["boiling water", "just-boiled", "hot water"]) && !recipe.equipment.contains(.pot)) {
            return .kettle
        }
        if has(["toast"]) { return .toast }
        if has(["oven", "bake", "roast", "broil"]) { return .oven }
        if has(["boil", "simmer", "poach", "blanch"]) { return .boil }
        if has(["fry", "fried", "saute", "sauté", "sear", "scrambl", "flip", "skillet", "wok", "melt",
                "heat the oil", "heat oil", "heat the butter"]) { return .fry }
        if has(["chop", "slice", "dice", "mince", "cut", "grate", "peel", "shred", "halve", "crush",
                "mash", "crumble", "prick", "pierce", "scrub", "zest", "flake"]) { return .chop }
        // Stirring something that's cooking happens over the heat, not in a bowl.
        if step.timer != nil || has(["cook", "heat", "cover", "minute"]), let heated = heatScene(for: recipe) {
            return heated
        }
        if has(["stir", "mix", "whisk", "combine", "toss", "blend", "beat", "fold", "season", "drizzle",
                "spread", "dress", "coat", "marinate", "crack", "pour", "add"]) { return .mix }
        if has(["serve", "plate", "top", "garnish", "enjoy", "eat", "spoon", "build", "assemble", "layer",
                "fill", "roll", "wrap", "squeeze", "finish", "sprinkle"]) { return .serve }
        if has(["chill", "fridge", "refrigerat", "overnight", "rest", "cool", "soak", "freez"]) { return .chill }
        if has(["drain"]) { return .boil }
        return heatScene(for: recipe) ?? .prep
    }

    /// The scene for the recipe's main piece of kit, when it has one.
    private static func heatScene(for recipe: Recipe) -> CookScene? {
        let order: [(Equipment, CookScene)] = [(.pan, .fry), (.pot, .boil), (.oven, .oven),
                                               (.microwave, .microwave), (.toaster, .toast), (.kettle, .kettle)]
        return order.first { recipe.equipment.contains($0.0) }?.1
    }

    /// Which of the two looks a step gets. It depends only on the recipe and
    /// the step, so going back to a step shows the same scene, but each recipe
    /// looks a little different. (Swift's own hash values change every launch.)
    static func variant(recipeID: String, step: Int) -> Int {
        (recipeID.unicodeScalars.reduce(step) { $0 &+ Int($1.value) }) % 2
    }

    /// A short name for the kit in use, shown under the step number.
    var tool: (title: String, symbol: String)? {
        switch self {
        case .boil: ("Pot", "cooktop")
        case .fry: ("Frying pan", "frying.pan")
        case .oven: ("Oven", "oven")
        case .microwave: ("Microwave", "microwave")
        case .kettle: ("Kettle", "mug")
        case .toast: ("Toaster", "flame")
        case .chop: ("Knife and board", "carrot")
        case .mix: ("Bowl", "basket")
        case .serve: ("Plate", "fork.knife")
        case .check: ("Food safety", "thermometer.medium")
        case .chill: ("Fridge", "refrigerator")
        case .prep: nil
        }
    }

    /// What VoiceOver says about the scene.
    var accessibilityLabel: String {
        switch self {
        case .boil: "Nutmeg stirring a bubbling pot"
        case .fry: "Nutmeg frying in a pan"
        case .oven: "Nutmeg watching the oven"
        case .microwave: "Nutmeg watching the microwave"
        case .kettle: "Nutmeg boiling the kettle"
        case .toast: "Nutmeg waiting for the toaster"
        case .chop: "Nutmeg chopping on a board"
        case .mix: "Nutmeg mixing in a bowl"
        case .serve: "Nutmeg serving up the dish"
        case .check: "Nutmeg checking the food is cooked through"
        case .chill: "Nutmeg chilling something in the fridge"
        case .prep: "Nutmeg reading the recipe"
        }
    }
}
