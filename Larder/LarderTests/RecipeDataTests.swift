//
//  RecipeDataTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/21/26.
//

import Testing
@testable import Larder

/// Checks on the bundled recipes themselves: that they're complete, that they
/// only use ingredients the app knows, and that the risky ones say how to cook
/// them safely.
@MainActor
struct RecipeDataTests {
    private let recipes = RecipeStore.all

    @Test func thirtyRecipesLoad() {
        #expect(recipes.count == 30)
    }

    @Test func idsAreUniqueAndContentIsFilledIn() {
        #expect(Set(recipes.map(\.id)).count == recipes.count)
        for recipe in recipes {
            #expect(!recipe.title.isEmpty, "\(recipe.id) has no title")
            #expect(!recipe.tip.isEmpty, "\(recipe.id) has no tip")
            #expect(recipe.minutes > 0 && recipe.servings >= 1, "\(recipe.id) has bad time or servings")
            #expect(recipe.ingredients.contains { !$0.isOptional && !IngredientPrices.assumedStaples.contains($0.id) },
                    "\(recipe.id) needs at least one real required ingredient")
        }
    }

    @Test func everyIngredientAndSwapIsInTheCatalog() {
        for recipe in recipes {
            for line in recipe.ingredients {
                #expect(IngredientCatalog.ingredient(withID: line.id) != nil, "\(recipe.id): unknown ingredient \(line.id)")
                for alt in line.alternatives {
                    #expect(IngredientCatalog.ingredient(withID: alt) != nil, "\(recipe.id): unknown swap \(alt)")
                }
            }
        }
    }

    @Test func everyRealIngredientHasAPrice() {
        for recipe in recipes {
            for line in recipe.ingredients where !IngredientPrices.assumedStaples.contains(line.id) {
                #expect(IngredientPrices.table[line.id] != nil, "\(recipe.id): no price for \(line.id)")
            }
        }
    }

    @Test func stepsAreWellFormed() {
        for recipe in recipes {
            #expect(recipe.steps.count >= 3, "\(recipe.id) has too few steps")
            for step in recipe.steps {
                #expect(!step.text.isEmpty)
                if let timer = step.timer {
                    #expect((10...10_800).contains(timer), "\(recipe.id): odd timer \(timer)s")
                }
            }
        }
    }

    @Test func costsAreBelievable() {
        for recipe in recipes {
            #expect((0.3...6).contains(recipe.costPerServing),
                    "\(recipe.id) costs \(recipe.costPerServing) per serving")
        }
    }

    // MARK: - Safety

    @Test func chickenRecipesStateTheSafeTemperature() {
        for recipe in recipes where recipe.ingredients.contains(where: { $0.id == "chicken" && !$0.isOptional }) {
            let text = recipe.steps.map(\.text).joined(separator: " ")
            #expect(text.contains("74°C") && text.contains("165°F"), "\(recipe.id) doesn't state the chicken temperature")
        }
    }

    @Test func sausageRecipesStateTheSafeTemperature() {
        for recipe in recipes where recipe.ingredients.contains(where: { $0.id == "sausage" && !$0.isOptional }) {
            let text = recipe.steps.map(\.text).joined(separator: " ")
            #expect(text.contains("71°C") && text.contains("160°F"), "\(recipe.id) doesn't state the sausage temperature")
        }
    }

    @Test func recipesWithEggsCookThemThrough() {
        // No recipe here calls for raw or runny eggs, which matters for people
        // who are pregnant, elderly, or unwell.
        for recipe in recipes where recipe.ingredients.contains(where: { $0.id == "egg" && !$0.isOptional }) {
            let text = recipe.steps.map(\.text).joined(separator: " ").lowercased()
            #expect(!text.contains("runny yolk") && !text.contains("soft yolk") && !text.contains("raw egg"),
                    "\(recipe.id) mentions undercooked eggs")
        }
    }

    // MARK: - Coverage

    @Test func everyDietHasEnoughRecipes() {
        func count(_ diet: Diet) -> Int { recipes.filter { $0.isCompatible(with: [diet]) }.count }
        #expect(count(.vegetarian) >= 15)
        #expect(count(.vegan) >= 6)
        #expect(count(.glutenFree) >= 5)
        #expect(count(.dairyFree) >= 12)
        #expect(count(.nutFree) >= 20)
        #expect(count(.halal) >= 20)
    }

    @Test func plentyOfRecipesWorkWithoutAStove() {
        #expect(recipes.filter(\.needsNoStove).count >= 8)
    }

    @Test func dietTraitsComeFromTheIngredients() {
        let friedRice = RecipeStore.recipe(withID: "egg-fried-rice")
        #expect(friedRice?.traits.contains(.egg) == true)
        #expect(friedRice?.traits.contains(.gluten) == true)      // soy sauce
        #expect(friedRice?.traits.contains(.meat) == false)

        let lentilSoup = RecipeStore.recipe(withID: "lentil-soup")
        #expect(lentilSoup?.traits.isEmpty == true)

        #expect(RecipeStore.recipe(withID: "sausage-pepper-pasta")?.traits.contains(.pork) == true)
    }

    @Test func optionalToppingsDoNotChangeADietLabel() {
        // Honey is an optional drizzle on the oatmeal, so it stays vegan.
        #expect(RecipeStore.recipe(withID: "microwave-oatmeal")?.isCompatible(with: [.vegan]) == true)
        #expect(RecipeStore.recipe(withID: "egg-fried-rice")?.isCompatible(with: [.vegan]) == false)
    }
}
