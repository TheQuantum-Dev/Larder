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

    @Test func theWholeBookLoads() {
        #expect(recipes.count == 61)
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

    /// Every recipe that uses this ingredient as a required line must say what
    /// temperature to check, in both units.
    private func expectTemperature(for id: String, _ celsius: String, _ fahrenheit: String, _ what: String) {
        let matching = recipes.filter { $0.ingredients.contains { $0.id == id && !$0.isOptional } }
        #expect(!matching.isEmpty, "no recipe uses \(id)")
        for recipe in matching {
            let text = recipe.steps.map(\.text).joined(separator: " ")
            #expect(text.contains(celsius) && text.contains(fahrenheit), "\(recipe.id) doesn't state the \(what) temperature")
        }
    }

    @Test func groundBeefStatesTheSafeTemperature() {
        expectTemperature(for: "beef", "71°C", "160°F", "beef")
    }

    @Test func turkeyStatesTheSafeTemperature() {
        expectTemperature(for: "turkey", "74°C", "165°F", "turkey")
    }

    @Test func porkStatesTheSafeTemperature() {
        expectTemperature(for: "pork", "63°C", "145°F", "pork")
    }

    @Test func fishStatesTheSafeTemperature() {
        expectTemperature(for: "fish", "63°C", "145°F", "fish")
    }

    @Test func shrimpRecipesSayToCookUntilOpaque() {
        for recipe in recipes where recipe.ingredients.contains(where: { $0.id == "shrimp" && !$0.isOptional }) {
            let text = recipe.steps.map(\.text).joined(separator: " ").lowercased()
            #expect(text.contains("opaque"), "\(recipe.id) doesn't say when the shrimp is done")
        }
    }

    @Test func baconIsCookedUntilCrisp() {
        for recipe in recipes where recipe.ingredients.contains(where: { $0.id == "bacon" && !$0.isOptional }) {
            let text = recipe.steps.map(\.text).joined(separator: " ").lowercased()
            #expect(text.contains("crisp"), "\(recipe.id) doesn't say to cook the bacon until crisp")
        }
    }

    @Test func recipesThatHandleRawMeatSayToWashUp() {
        let raw: Set<String> = ["chicken", "beef", "turkey", "pork"]
        // Leftover cooked chicken (the wrap) isn't raw, so it's left out.
        func usesRawMeat(_ line: RecipeIngredient) -> Bool {
            raw.contains(line.id) && !line.isOptional && line.nutri != "chicken-cooked"
        }
        for recipe in recipes where recipe.ingredients.contains(where: usesRawMeat) {
            let text = recipe.steps.map(\.text).joined(separator: " ").lowercased()
            #expect(text.contains("wash") && text.contains("raw"), "\(recipe.id) never says to wash up after raw meat")
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
        #expect(count(.vegan) >= 12)
        #expect(count(.glutenFree) >= 10)
        #expect(count(.dairyFree) >= 25)
        #expect(count(.nutFree) >= 40)
        #expect(count(.halal) >= 40)
    }

    @Test func plentyOfRecipesWorkWithoutAStove() {
        #expect(recipes.filter(\.needsNoStove).count >= 12)
    }

    @Test func kettleAndOvenRecipesExist() {
        #expect(recipes.contains { $0.equipment.contains(.kettle) })
        #expect(recipes.contains { $0.equipment.contains(.oven) })
    }

    @Test func everyGoalHasPlentyToChooseFrom() {
        let protein = recipes.filter { $0.nutrition.protein >= RecipeFilter.highProteinGrams }.count
        let light = recipes.filter { $0.nutrition.kcal <= RecipeFilter.lighterKcal }.count
        let hearty = recipes.filter { $0.nutrition.kcal >= RecipeFilter.heartyKcal }.count
        #expect(protein >= 15, "only \(protein) high-protein recipes")
        #expect(light >= 8, "only \(light) lighter recipes")
        #expect(hearty >= 8, "only \(hearty) hearty recipes")
    }

    @Test func eachDietStillHasHighProteinAndLighterOptions() {
        for diet in Diet.allCases where diet != .noRestrictions {
            let fitting = recipes.filter { $0.isCompatible(with: [diet]) }
            let protein = fitting.filter { $0.nutrition.protein >= RecipeFilter.highProteinGrams }.count
            let light = fitting.filter { $0.nutrition.kcal <= RecipeFilter.lighterKcal }.count
            #expect(protein >= 3, "\(diet) has only \(protein) high-protein recipes")
            #expect(light >= 3, "\(diet) has only \(light) lighter recipes")
        }
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
