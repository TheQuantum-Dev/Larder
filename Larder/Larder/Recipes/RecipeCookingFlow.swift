//
//  RecipeCookingFlow.swift
//  Larder
//
//  Created by Joshua Samuel on 9/21/26.
//

import SwiftUI

/// Attaches the whole "open a recipe, then cook it" flow to any screen that
/// shows recipes: pick one and its sheet opens, and "Let's cook this" hands
/// over to Cook Mode. Home and the recipe list both use it.
private struct RecipeCookingFlow: ViewModifier {
    @Binding var selected: RecipeMatch?
    let diets: Set<Diet>
    let showsNutrition: Bool
    let onCooked: (Recipe) -> Void

    @State private var cooking: Recipe?

    func body(content: Content) -> some View {
        content
            .sheet(item: $selected) { match in
                RecipeDetailView(match: match, diets: diets, showsNutrition: showsNutrition) { recipe in
                    selected = nil
                    // Let the sheet finish closing before Cook Mode takes over.
                    Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        cooking = recipe
                    }
                }
            }
            .fullScreenCover(item: $cooking) { recipe in
                CookModeView(recipe: recipe, diets: diets,
                             onFinish: {
                                 cooking = nil
                                 onCooked(recipe)
                             },
                             onClose: { cooking = nil })
            }
    }
}

extension View {
    func recipeCookingFlow(selected: Binding<RecipeMatch?>, diets: Set<Diet>, showsNutrition: Bool = true,
                           onCooked: @escaping (Recipe) -> Void = { _ in }) -> some View {
        modifier(RecipeCookingFlow(selected: selected, diets: diets, showsNutrition: showsNutrition, onCooked: onCooked))
    }
}
