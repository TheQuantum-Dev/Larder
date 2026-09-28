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
    case drain, crack, season, spread, mash, whisk

    /// A scene and which of its three looks to show.
    struct Staging: Equatable, Sendable {
        let scene: CookScene
        let variant: Int
    }

    /// What's being chopped, so the board shows the right thing (and an onion
    /// gets swim goggles).
    enum Produce: Sendable { case carrot, onion, tomato, greens }

    static let variants = 3

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
        // Toasting, as something to do, not toast as something to spread on.
        if text.hasPrefix("toast") || has(["toaster", "toast the", "toast it", "toast bread", "toast for", "toast until"]) {
            return .toast
        }
        if has(["oven", "bake", "roast", "broil"]) { return .oven }
        if has(["boil", "simmer", "poach", "blanch"]) { return .boil }
        if has(["fry", "fried", "saute", "sauté", "sear", "scrambl", "flip", "skillet", "wok", "melt",
                "heat the oil", "heat oil", "heat the butter"]) { return .fry }
        if has(["drain", "strain", "colander", "rinse"]) { return .drain }
        if has(["mash"]) { return .mash }
        if has(["crack"]) { return .crack }
        if has(["chop", "slice", "dice", "mince", "cut", "grate", "peel", "shred", "halve", "crush",
                "crumble", "prick", "pierce", "scrub", "zest", "flake"]) { return .chop }
        // Stirring something that's cooking happens over the heat, not in a bowl.
        if step.timer != nil || has(["cook", "heat", "cover", "minute"]), let heated = heatScene(for: recipe) {
            return heated
        }
        if has(["whisk", "beat"]) { return .whisk }
        if has(["spread", "butter the", "smear"]) { return .spread }
        // Seasoning on its own; "serve with a sprinkle" is still serving.
        if has(["season", "salt and pepper", "pinch of", "sprinkle"]), !has(["serve", "plate"]) { return .season }
        if has(["stir", "mix", "combine", "toss", "blend", "fold", "drizzle",
                "dress", "coat", "marinate", "pour", "add"]) { return .mix }
        if has(["serve", "plate", "top", "garnish", "enjoy", "eat", "spoon", "build", "assemble", "layer",
                "fill", "roll", "wrap", "squeeze", "finish"]) { return .serve }
        if has(["chill", "fridge", "refrigerat", "overnight", "rest", "cool", "soak", "freez"]) { return .chill }
        return heatScene(for: recipe) ?? .prep
    }

    /// The scene for the recipe's main piece of kit, when it has one.
    private static func heatScene(for recipe: Recipe) -> CookScene? {
        let order: [(Equipment, CookScene)] = [(.pan, .fry), (.pot, .boil), (.oven, .oven),
                                               (.microwave, .microwave), (.toaster, .toast), (.kettle, .kettle)]
        return order.first { recipe.equipment.contains($0.0) }?.1
    }

    /// Which of the three looks a step gets. It depends only on the recipe and
    /// the step, so going back to a step shows the same scene, but each recipe
    /// looks a little different. (Swift's own hash values change every launch.)
    static func variant(recipeID: String, step: Int) -> Int {
        (recipeID.unicodeScalars.reduce(step) { $0 &+ Int($1.value) }) % variants
    }

    /// The scene for every step of a recipe. When two steps in a row land on
    /// the same scene, the second gets a different look, so frying three
    /// steps running still looks like three different moments.
    static func plan(for recipe: Recipe) -> [Staging] {
        var plan: [Staging] = []
        for index in recipe.steps.indices {
            let scene = CookScene.for(step: index, in: recipe)
            var variant = variant(recipeID: recipe.id, step: index)
            if let previous = plan.last, previous.scene == scene, previous.variant == variant {
                variant = (variant + 1) % variants
            }
            plan.append(Staging(scene: scene, variant: variant))
        }
        return plan
    }

    /// What a chopping step is cutting up, from its words.
    static func produce(in text: String) -> Produce {
        let lower = text.lowercased()
        if lower.contains("onion") || lower.contains("shallot") { return .onion }
        if lower.contains("tomato") || lower.contains("pepper") || lower.contains("chili") { return .tomato }
        if ["lettuce", "spinach", "cabbage", "herb", "parsley", "cilantro", "basil", "kale", "scallion", "green onion"]
            .contains(where: lower.contains) { return .greens }
        return .carrot
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
        case .drain: ("Colander", "drop")
        case .crack: ("Bowl", "oval")
        case .season: ("Salt and pepper", "sparkles")
        case .spread: ("Butter knife", "square.stack")
        case .mash: ("Masher", "fork.knife")
        case .whisk: ("Whisk", "tornado")
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
        case .drain: "Nutmeg draining a pot into a colander"
        case .crack: "Nutmeg cracking an egg into a bowl"
        case .season: "Nutmeg grinding pepper over the food"
        case .spread: "Nutmeg spreading butter on toast"
        case .mash: "Nutmeg mashing in a bowl"
        case .whisk: "Nutmeg whisking in a bowl"
        }
    }
}
