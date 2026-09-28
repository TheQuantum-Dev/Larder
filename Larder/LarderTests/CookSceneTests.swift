//
//  CookSceneTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/26/26.
//

import Testing
@testable import Larder

struct CookSceneTests {
    private func recipe(_ steps: [String], equipment: [Equipment] = [], timer: Int? = nil) -> Recipe {
        Recipe(id: "test", title: "Test", emoji: "🍽️", minutes: 10, servings: 1, equipment: equipment,
               ingredients: [], steps: steps.map { RecipeStep(text: $0, timer: timer) }, tip: "", healthy: false)
    }

    private func scene(_ text: String, equipment: [Equipment] = [], timer: Int? = nil) -> CookScene {
        CookScene.for(step: 0, in: recipe([text], equipment: equipment, timer: timer))
    }

    @Test func stepsGetTheSceneTheirWordsDescribe() {
        #expect(scene("Check that the chicken has reached 74°C (165°F).") == .check)
        #expect(scene("Microwave for 2 minutes, stirring halfway.") == .microwave)
        #expect(scene("Bring a pot of water to the boil and add the pasta.") == .boil)
        #expect(scene("Pour boiling water over the noodles.") == .kettle)
        #expect(scene("Toast the bread.") == .toast)
        #expect(scene("Heat the oil in a pan over medium heat.") == .fry)
        #expect(scene("Slice the onion thinly.") == .chop)
        #expect(scene("Whisk the eggs with a pinch of salt.") == .whisk)
        #expect(scene("Serve with a squeeze of lemon.") == .serve)
        #expect(scene("Leave in the fridge overnight.") == .chill)
    }

    @Test func cookingWithoutAVerbUsesTheRecipesKit() {
        #expect(scene("Add the onion and garlic and cook 2 minutes.", equipment: [.pan]) == .fry)
        #expect(scene("Add the noodles and cook for the time on the pack.", equipment: [.pot]) == .boil)
        // Stirring something on the heat happens in the pan, not in a bowl.
        #expect(scene("Stir in the rice.", equipment: [.pan], timer: 120) == .fry)
        #expect(scene("Stir in the rice.") == .mix)
    }

    @Test func waterBoiledInAPotIsThePotNotTheKettle() {
        #expect(scene("Boil 500 ml of water in a pot. Take care with the boiling water.", equipment: [.pot]) == .boil)
        #expect(scene("Pour boiling water over the couscous.", equipment: [.kettle]) == .kettle)
    }

    @Test func somethingUnclearIsJustReadingTheRecipe() {
        #expect(scene("Get everything ready.") == .prep)
        #expect(CookScene.for(step: 5, in: recipe(["Toast the bread."])) == .prep)
    }

    @Test func theAddedFoodSafetyStepIsACheck() {
        let safety = "Food safety: cook meat, poultry and fish all the way through (chicken and turkey to 165°F / 74°C)."
        #expect(scene(safety, equipment: [.pan]) == .check)
    }

    @Test func nearlyEveryBundledStepGetsARealScene() {
        let steps = RecipeStore.all.flatMap { recipe in recipe.steps.indices.map { CookScene.for(step: $0, in: recipe) } }
        let prep = steps.filter { $0 == .prep }.count
        #expect(Double(prep) / Double(steps.count) < 0.1)
        // And the scenes are spread around, not all one kind.
        #expect(Set(steps).count >= 10)
    }

    @Test func theNewScenesHaveTheirOwnWords() {
        #expect(scene("Drain the pasta, keeping a splash of the water.") == .drain)
        #expect(scene("Rinse the beans in a sieve.") == .drain)
        #expect(scene("Crack the eggs into a bowl.") == .crack)
        #expect(scene("Mash the potato with a fork.") == .mash)
        #expect(scene("Spread the peanut butter on the toast.", equipment: []) == .spread)
        #expect(scene("Season with salt and pepper.") == .season)
        #expect(scene("Beat the eggs until smooth.") == .whisk)
        // A sprinkle to finish is still serving.
        #expect(scene("Serve with a sprinkle of cheese.") == .serve)
    }

    @Test func choppingKnowsWhatItsCutting() {
        #expect(CookScene.produce(in: "Dice the onion.") == .onion)
        #expect(CookScene.produce(in: "Slice the tomato.") == .tomato)
        #expect(CookScene.produce(in: "Shred the spinach.") == .greens)
        #expect(CookScene.produce(in: "Grate the carrot.") == .carrot)
    }

    @Test func noTwoStepsInARowLookTheSame() {
        for recipe in RecipeStore.all {
            let plan = CookScene.plan(for: recipe)
            #expect(plan.count == recipe.steps.count)
            for (a, b) in zip(plan, plan.dropFirst()) {
                #expect(a != b, "\(recipe.id) repeats \(a.scene)")
            }
        }
    }

    @Test func thePlanIsTheSameEveryTime() {
        let recipe = RecipeStore.recipe(withID: "egg-fried-rice")!
        #expect(CookScene.plan(for: recipe) == CookScene.plan(for: recipe))
    }

    @Test func theVariantIsTheSameEveryTime() {
        let first = CookScene.variant(recipeID: "egg-fried-rice", step: 2)
        #expect(CookScene.variant(recipeID: "egg-fried-rice", step: 2) == first)
        #expect((0..<CookScene.variants).contains(first))
        #expect(CookScene.variant(recipeID: "egg-fried-rice", step: 3) != first)
    }
}
