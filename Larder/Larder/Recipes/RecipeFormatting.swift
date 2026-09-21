//
//  RecipeFormatting.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import Foundation

nonisolated extension Recipe {
    /// "about $1.30", for a per-serving cost that is only ever a rough guess.
    var costText: String {
        "about " + costPerServing.formatted(.currency(code: "USD"))
    }

    /// The ingredient lines to show for a diet: optional extras the diet rules
    /// out (like honey for someone vegan) are left off instead of shown.
    func visibleIngredients(for diets: Set<Diet>) -> [RecipeIngredient] {
        let forbidden = Diet.forbiddenTraits(for: diets)
        return ingredients.filter { line in
            guard line.isOptional else { return true }
            let traits = IngredientCatalog.ingredient(withID: line.id)?.traits ?? []
            return traits.isDisjoint(with: forbidden)
        }
    }
}

nonisolated enum TimerText {
    /// 90 becomes "1 min 30 sec", 300 becomes "5 min", 45 becomes "45 sec".
    static func text(seconds: Int) -> String {
        let minutes = seconds / 60
        let rest = seconds % 60
        switch (minutes, rest) {
        case (0, _): return "\(rest) sec"
        case (_, 0): return "\(minutes) min"
        default: return "\(minutes) min \(rest) sec"
        }
    }
}
