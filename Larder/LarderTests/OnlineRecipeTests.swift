//
//  OnlineRecipeTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation
import Testing
@testable import Larder

/// The recipes that come from online, tried on made-up sample data: how they
/// turn into the app's own recipes, how they're matched to the pantry, and what
/// they're allowed to claim about a person's diet.
struct OnlineRecipeMapperTests {
    private func samples() throws -> [OnlineRecipeDTO] {
        try JSONDecoder().decode(OnlineSearchResponse.self, from: Data(FakeRecipeAPI.sampleJSON.utf8)).results
    }

    private func mapped(_ id: Int) throws -> Recipe {
        let dto = try #require(try samples().first { $0.id == id })
        return try #require(OnlineRecipeMapper.recipe(from: dto))
    }

    // MARK: - Reading the response

    @Test func theSampleResponseDecodesAndMaps() throws {
        let dtos = try samples()
        #expect(dtos.count == 6)
        #expect(dtos.compactMap(OnlineRecipeMapper.recipe(from:)).count == 6)
    }

    @Test func oneBrokenRecipeDoesNotLoseTheRest() throws {
        let json = #"{"results": [{"id": "not a number", "title": "Broken"}, {"id": 7, "title": "Fine"}]}"#
        let response = try JSONDecoder().decode(OnlineSearchResponse.self, from: Data(json.utf8))
        #expect(response.results.map(\.id) == [7])
    }

    // MARK: - The recipe it makes

    @Test func aRecipeCarriesItsBasics() throws {
        let recipe = try mapped(900001)
        #expect(recipe.id == "sp-900001")
        #expect(recipe.title == "Sesame chicken rice bowl")
        #expect(recipe.minutes == 25)
        #expect(recipe.servings == 2)
        #expect(recipe.isOnline)
        #expect(recipe.source?.name == "Weeknight Bowls")
        #expect(recipe.source?.url == "https://example.com/sesame-chicken-rice-bowl")
        #expect(recipe.healthy)
        #expect(recipe.meals == ["lunch", "dinner"])
    }

    @Test func costAndNumbersComeFromTheSource() throws {
        let recipe = try mapped(900001)
        #expect(abs(recipe.costPerServing - 2.15) < 0.001)
        #expect(recipe.nutrition == Macros(kcal: 560, protein: 44, carbs: 52, fat: 16))
        #expect(recipe.costText == "about $2.15")
    }

    @Test func timersComeFromEachStepsLength() throws {
        let recipe = try mapped(900001)
        #expect(recipe.steps[1].timer == 360)
        #expect(recipe.steps[2].timer == 240)
        #expect(recipe.steps[0].timer == nil)
    }

    @Test func recipesWithMeatGetTheSafeTemperaturesAsALastStep() throws {
        let chicken = try mapped(900001)
        #expect(chicken.steps.last?.text == OnlineRecipeMapper.safetyStep)
        #expect(chicken.steps.last?.timer == nil)
        #expect(chicken.steps.count == 5)
        // Eggs count too; oats and fruit don't.
        #expect(try mapped(900002).steps.last?.text == OnlineRecipeMapper.safetyStep)
        #expect(try mapped(900004).steps.last?.text != OnlineRecipeMapper.safetyStep)
    }

    @Test func breakfastsAreTaggedForBreakfastAndMainCoursesForLunchAndDinner() throws {
        #expect(try mapped(900002).meals == ["breakfast", "lunch"])
        #expect(try mapped(900004).meals == ["breakfast"])
        #expect(try mapped(900005).meals == ["lunch", "dinner"])
    }

    @Test func equipmentIsReadFromTheSteps() throws {
        #expect(try mapped(900001).equipment == [.pan])
        #expect(try mapped(900003).equipment == [.pot, .oven])
        #expect(try mapped(900005).equipment == [.pot])
        // A bowl of yogurt needs no cooking equipment at all.
        #expect(try mapped(900004).equipment.isEmpty)
        #expect(try mapped(900004).needsNoStove)
        #expect(try !mapped(900006).needsNoStove)
    }

    @Test func stepTextFillsInEquipmentTheServiceLeftOut() {
        let step = OnlineStepDTO(step: "Bake it in the oven until golden.", equipment: nil, length: nil)
        #expect(OnlineRecipeMapper.equipment(from: [step], text: step.step) == [.oven])
        let plain = OnlineStepDTO(step: "Toss everything together.", equipment: nil, length: nil)
        #expect(OnlineRecipeMapper.equipment(from: [plain], text: plain.step).isEmpty)
    }

    @Test func aSourceNameFallsBackToTheSitesAddress() {
        let json = #"{"id": 1, "title": "x", "sourceUrl": "https://www.example.org/a/b"}"#
        let dto = try? JSONDecoder().decode(OnlineRecipeDTO.self, from: Data(json.utf8))
        #expect(dto.map(OnlineRecipeMapper.sourceName(for:)) == "example.org")
    }

    @Test func aRecipeWithoutStepsIngredientsOrNumbersIsLeftOut() throws {
        let good = try #require(try samples().first)
        func variant(_ change: (inout [String: Any]) -> Void) throws -> OnlineRecipeDTO {
            var object = try #require(try JSONSerialization.jsonObject(
                with: Data(FakeRecipeAPI.sampleJSON.utf8)) as? [String: Any])
            var results = try #require(object["results"] as? [[String: Any]])
            var first = results[0]
            change(&first)
            results[0] = first
            object["results"] = results
            let data = try JSONSerialization.data(withJSONObject: object)
            return try #require(try JSONDecoder().decode(OnlineSearchResponse.self, from: data).results.first)
        }
        #expect(OnlineRecipeMapper.recipe(from: good) != nil)
        #expect(OnlineRecipeMapper.recipe(from: try variant { $0["analyzedInstructions"] = [] }) == nil)
        #expect(OnlineRecipeMapper.recipe(from: try variant { $0["extendedIngredients"] = [] }) == nil)
        #expect(OnlineRecipeMapper.recipe(from: try variant { $0["nutrition"] = ["nutrients": []] }) == nil)
    }

    @Test func timersAreConvertedAndKeptInRange() {
        func seconds(_ number: Double, _ unit: String) -> Int? {
            OnlineRecipeMapper.seconds(from: OnlineLengthDTO(number: number, unit: unit))
        }
        #expect(seconds(5, "minutes") == 300)
        #expect(seconds(2, "hours") == 7_200)
        #expect(seconds(45, "seconds") == 45)
        #expect(seconds(1, "seconds") == 10)
        #expect(seconds(10, "hours") == 10_800)
        #expect(seconds(3, "days") == nil)
        #expect(OnlineRecipeMapper.seconds(from: nil) == nil)
    }

    @Test func aRecipeSurvivesBeingEncodedAndDecoded() throws {
        let recipe = try mapped(900001)
        let copy = try JSONDecoder().decode(Recipe.self, from: JSONEncoder().encode(recipe))
        #expect(copy == recipe)
        #expect(copy.nutrition == recipe.nutrition)
    }

    // MARK: - Diets

    @Test func theServicesLabelsBecomeDietFlags() throws {
        let chicken = try mapped(900001)
        #expect(chicken.traits.contains(.meat))
        #expect(!chicken.isCompatible(with: [.vegetarian]))
        #expect(!chicken.isCompatible(with: [.vegan]))
        #expect(!chicken.isCompatible(with: [.glutenFree]))
        #expect(chicken.isCompatible(with: [.dairyFree]))

        let wrap = try mapped(900002)
        #expect(wrap.isCompatible(with: [.vegetarian]))
        #expect(!wrap.isCompatible(with: [.vegan]))
        #expect(!wrap.isCompatible(with: [.dairyFree]))

        let stew = try mapped(900006)
        #expect(stew.isCompatible(with: [.vegan, .glutenFree, .dairyFree]))
    }

    @Test func wordsInTheIngredientsCatchWhatALabelMisses() throws {
        func recipe(vegetarian: Bool, ingredient: String) throws -> Recipe {
            let json = """
            {"id": 42, "title": "Test", "servings": 2, "readyInMinutes": 20, "pricePerServing": 200,
             "vegetarian": \(vegetarian), "vegan": \(vegetarian), "glutenFree": true, "dairyFree": true,
             "extendedIngredients": [{"nameClean": "rice", "original": "1 cup rice"},
                                     {"nameClean": "x", "original": "\(ingredient)"}],
             "analyzedInstructions": [{"steps": [{"number": 1, "step": "Mix it."}]}],
             "nutrition": {"nutrients": [{"name": "Calories", "amount": 400, "unit": "kcal"}]}}
            """
            return try #require(OnlineRecipeMapper.recipe(from: JSONDecoder().decode(OnlineRecipeDTO.self,
                                                                                    from: Data(json.utf8))))
        }
        // Labelled vegetarian, but the ingredients say bacon.
        let bacon = try recipe(vegetarian: true, ingredient: "4 slices bacon, chopped")
        #expect(bacon.traits.contains(.pork))
        #expect(!bacon.isCompatible(with: [.halal]))
        #expect(!bacon.isCompatible(with: [.vegetarian]))

        let wine = try recipe(vegetarian: true, ingredient: "1/2 cup white wine")
        #expect(wine.traits.contains(.alcohol))
        #expect(!wine.isCompatible(with: [.halal]))

        let nuts = try recipe(vegetarian: true, ingredient: "1/4 cup chopped walnuts")
        #expect(nuts.traits.contains(.nuts))
        #expect(!nuts.isCompatible(with: [.nutFree]))

        // "Hamburger" and "ginger" are not ham and gin.
        let fine = try recipe(vegetarian: true, ingredient: "1 tbsp grated ginger")
        #expect(!fine.traits.contains(.alcohol))
        #expect(!fine.traits.contains(.pork))
    }

    // MARK: - Ingredient matching

    @Test func namesMatchTheCatalogOnlyWhenTheyClearlyAreThatIngredient() {
        let cases: [(name: String, id: String)] = [
            ("chicken breast", "chicken"), ("chicken breasts", "chicken"),
            ("boneless skinless chicken thighs", "chicken"),
            ("eggs", "egg"), ("egg whites", "egg"),
            ("rice", "rice"), ("cooked rice", "rice"), ("basmati rice", "rice"),
            ("broccoli florets", "broccoli"), ("soy sauce", "soy-sauce"),
            ("garlic", "garlic"), ("garlic cloves", "garlic"),
            ("cheddar cheese", "cheese"), ("mozzarella cheese", "cheese"), ("parmesan cheese", "cheese"),
            ("goat cheese", "cheese"),
            ("milk", "milk"), ("whole milk", "milk"),
            ("black beans", "beans"), ("kidney beans", "beans"), ("chickpeas", "beans"),
            ("salt", "salt"), ("kosher salt", "salt"), ("pepper", "black-pepper"), ("black pepper", "black-pepper"),
            ("olive oil", "olive-oil"), ("extra virgin olive oil", "olive-oil"), ("vegetable oil", "cooking-oil"),
            ("red onion", "onion"), ("yellow onion", "onion"), ("green onions", "onion"), ("sweet onion", "onion"),
            ("red bell pepper", "bell-pepper"), ("ground beef", "beef"), ("ground turkey", "turkey"),
            ("salmon fillets", "fish"), ("chicken broth", "broth"), ("unsalted butter", "butter"),
            ("spaghetti", "pasta"), ("tortillas", "tortilla"), ("greek yogurt", "yogurt"), ("rolled oats", "oats"),
            ("lemon juice", "lemon"), ("warm water", "water"), ("tomato sauce", "tomato-sauce"),
            ("tomato paste", "tomato-sauce"), ("cherry tomatoes", "tomato"), ("flat leaf parsley", "herbs"),
            ("baby spinach", "spinach"), ("sweet potatoes", "sweet-potato"),
        ]
        for c in cases {
            #expect(OnlineIngredientMapper.id(forName: c.name) == c.id, "\(c.name)")
        }
    }

    @Test func seasoningsCountAsStaplesSoTheyNeverBlockARecipe() {
        for name in ["cumin", "chili powder", "smoked paprika", "garam masala", "ground cinnamon", "baking powder",
                     "baking soda", "vanilla extract", "red pepper flakes", "italian seasoning", "bay leaf"] {
            #expect(OnlineIngredientMapper.id(forName: name) == "black-pepper", "\(name)")
        }
    }

    @Test func lookalikesAreNotGuessedAt() {
        // Each of these would wrongly look like something the person might have.
        #expect(OnlineIngredientMapper.id(forName: "coconut milk") == "custom:coconut milk")
        #expect(OnlineIngredientMapper.id(forName: "cauliflower rice") == "custom:cauliflower rice")
        #expect(OnlineIngredientMapper.id(forName: "heavy cream") == "custom:heavy cream")
        #expect(OnlineIngredientMapper.id(forName: "sesame seeds") == "custom:sesame seed")
        #expect(OnlineIngredientMapper.id(forName: "fish sauce") == "custom:fish sauce")
        #expect(OnlineIngredientMapper.id(forName: "rice vinegar") == "custom:rice vinegar")
        #expect(OnlineIngredientMapper.id(forName: "cream of mushroom soup").hasPrefix("custom:"))
    }

    @Test func customIngredientsAreShownAndListedByTheirName() {
        #expect(IngredientCatalog.displayName(forID: "custom:garam masala") == "Garam masala")
        #expect(IngredientCatalog.displayName(forID: "egg") == "Eggs")
        let item = IngredientCatalog.resolvedItem(forID: "custom:coconut milk")
        #expect(item?.isCustom == true)
        #expect(item?.name == "Coconut milk")
        #expect(item?.id == "custom:coconut milk")
        #expect(IngredientCatalog.resolvedItem(forID: "egg")?.isCustom == false)
        #expect(IngredientCatalog.resolvedItem(forID: "not-a-thing") == nil)
    }

    @Test func aRecipeIsReadyWhenThePantryCoversWhatItRecognises() throws {
        let bowl = try mapped(900001)
        // Chicken, rice, broccoli, soy sauce and garlic: all catalog ingredients; sesame seeds are the one custom one.
        let matches = RecipeMatcher.matches(recipes: [bowl], pantry: ["chicken", "rice", "broccoli", "soy-sauce", "garlic"])
        #expect(matches.first?.missing.map(\.id) == ["custom:sesame seed"])
        // The stew has coconut milk (custom) and a spice (a staple), so the missing one is named properly.
        let stew = try mapped(900006)
        let stewMatch = RecipeMatcher.matches(recipes: [stew], pantry: ["beans", "onion", "tomato-sauce"]).first
        #expect(stewMatch?.missing.map { IngredientCatalog.displayName(forID: $0.id) } == ["Coconut milk"])
    }
}

struct OnlineQueryTests {
    private func request(anchors: [String] = ["chicken", "rice"], goal: FitnessGoal? = nil, diets: Set<Diet> = [],
                         slot: MealSlot = .dinner) -> OnlineRequest {
        OnlineRequest(anchors: anchors, goal: goal, diets: diets, slot: slot)
    }

    private func value(_ name: String, in request: OnlineRequest) -> String? {
        OnlineQuery.items(for: request).first { $0.name == name }?.value
    }

    @Test func theSearchIsBuiltAroundThePantryAndTheMeal() {
        let r = request()
        #expect(value("includeIngredients", in: r) == "chicken,rice")
        #expect(value("sort", in: r) == "max-used-ingredients")
        #expect(value("type", in: r) == "main course")
        #expect(value("addRecipeInformation", in: r) == "true")
        #expect(value("addRecipeNutrition", in: r) == "true")
        #expect(value("instructionsRequired", in: r) == "true")
        #expect(value("number", in: r) == "10")
        #expect(value("type", in: request(slot: .breakfast)) == "breakfast")
        #expect(value("type", in: request(slot: .lunch)) == "main course")
    }

    @Test func theKeyNeverGoesInTheQuery() {
        let names = OnlineQuery.items(for: request(goal: .buildMuscle, diets: [.vegan, .halal])).map { $0.name.lowercased() }
        #expect(!names.contains { $0.contains("key") })
    }

    @Test func eachGoalAsksForWhatSuitsIt() {
        #expect(value("minProtein", in: request(goal: .buildMuscle)) == "30")
        #expect(value("maxCalories", in: request(goal: .loseWeight)) == "500")
        #expect(value("minProtein", in: request(goal: .loseWeight)) == "15")
        #expect(value("minCalories", in: request(goal: .gainWeight)) == "700")
        #expect(value("minProtein", in: request(goal: .stayFit)) == "20")
        #expect(value("maxCalories", in: request(goal: .stayFit)) == "700")
        for goal in [FitnessGoal.justCook, nil] {
            let names = OnlineQuery.items(for: request(goal: goal)).map(\.name)
            #expect(!names.contains("minProtein") && !names.contains("maxCalories") && !names.contains("minCalories"))
        }
    }

    @Test func onlyNutrientFiltersCostTheExtraPoint() {
        #expect(OnlineQuery.usesNutrientFilter(request(goal: .buildMuscle)))
        #expect(!OnlineQuery.usesNutrientFilter(request(goal: .justCook)))
        #expect(!OnlineQuery.usesNutrientFilter(request(goal: nil)))
    }

    @Test func dietsBecomeFiltersAndTheStricterVeganWins() {
        #expect(value("diet", in: request(diets: [.vegetarian])) == "vegetarian")
        #expect(value("diet", in: request(diets: [.vegetarian, .vegan])) == "vegan")
        #expect(value("diet", in: request(diets: [.vegetarian, .glutenFree])) == "vegetarian,gluten free")
        #expect(value("intolerances", in: request(diets: [.glutenFree, .dairyFree, .nutFree])) == "gluten,dairy,peanut,tree nut")
        #expect(value("diet", in: request(diets: [.dairyFree])) == nil)
        #expect(value("intolerances", in: request(diets: [])) == nil)
    }

    @Test func halalKeepsPorkAndAlcoholOut() {
        let excluded = value("excludeIngredients", in: request(diets: [.halal])) ?? ""
        #expect(excluded.contains("pork") && excluded.contains("bacon") && excluded.contains("wine"))
        #expect(value("excludeIngredients", in: request(diets: [.vegan])) == nil)
    }

    @Test func withNothingToBuildAroundThereIsNoIngredientFilter() {
        let r = request(anchors: [])
        #expect(value("includeIngredients", in: r) == nil)
        #expect(value("sort", in: r) == nil)
    }

    // MARK: - Choosing what to build around

    @Test func aProteinComesFirstThenSomethingToGoWithIt() {
        #expect(OnlineAnchors.pick(from: ["egg", "rice", "chicken", "onion"]) == ["chicken", "rice"])
        #expect(OnlineAnchors.pick(from: ["onion", "beef", "pasta"]) == ["beef", "pasta"])
    }

    @Test func withoutAProteinTheBestTwoOfTheRestAreUsed() {
        #expect(OnlineAnchors.pick(from: ["milk", "egg", "cheese", "rice"]) == ["rice", "egg"])
    }

    @Test func seasoningsSpreadsAndCustomItemsAreNeverAnchors() {
        #expect(OnlineAnchors.pick(from: ["salt", "garlic", "peanut-butter", "custom:kimchi", "milk"]).isEmpty)
        #expect(OnlineAnchors.pick(from: ["custom:kimchi", "tofu"]) == ["tofu"])
    }

    @Test func idsBecomeNamesTheServiceUnderstands() {
        #expect(OnlineAnchors.pick(from: ["sweet-potato"]) == ["sweet potato"])
        #expect(OnlineAnchors.pick(from: ["bell-pepper"]) == ["bell pepper"])
        #expect(OnlineAnchors.pick(from: []).isEmpty)
        #expect(OnlineAnchors.pick(from: ["chicken", "rice", "onion"], limit: 1) == ["chicken"])
    }
}

struct OnlineQuotaTests {
    private let day1 = Date(timeIntervalSince1970: 1_790_000_000)
    private var day2: Date { day1.addingTimeInterval(86_400) }

    @Test func aSearchCostsAPointPlusABitPerRecipe() {
        #expect(abs(OnlineQuota.searchCost(recipes: 10, nutrientFilter: false) - 1.85) < 0.001)
        #expect(abs(OnlineQuota.searchCost(recipes: 10, nutrientFilter: true) - 2.85) < 0.001)
    }

    @Test func spendingStopsBeforeTheAllowanceRunsOut() {
        var quota = OnlineQuota()
        quota.record(40, on: day1)
        #expect(quota.canSpend(5, on: day1))
        #expect(!quota.canSpend(5.5, on: day1))
        #expect(abs(quota.remaining(on: day1) - 10) < 0.001)
    }

    @Test func aNewDayStartsFresh() {
        var quota = OnlineQuota()
        quota.record(44, on: day1)
        #expect(quota.remaining(on: day2) == OnlineQuota.dailyPoints)
        #expect(quota.canSpend(3, on: day2))
        quota.record(2, on: day2)
        #expect(abs(quota.used - 2) < 0.001)
    }

    @Test func whenTheServiceSaysItsDoneItsDoneForTheDay() {
        var quota = OnlineQuota()
        quota.markExhausted(on: day1)
        #expect(!quota.canSpend(1, on: day1))
        #expect(quota.remaining(on: day1) == 0)
        #expect(quota.canSpend(1, on: day2))
    }

    @Test func theDayFollowsUTCMidnight() {
        // 2026-09-26 23:59:59 UTC and one second later.
        let before = Date(timeIntervalSince1970: 1_790_467_199)
        let after = Date(timeIntervalSince1970: 1_790_467_200)
        #expect(OnlineQuota.dayKey(for: before) == "2026-09-26")
        #expect(OnlineQuota.dayKey(for: after) == "2026-09-27")
    }

    @Test func theCountSurvivesBeingSavedAndLoaded() throws {
        let defaults = try #require(UserDefaults(suiteName: "OnlineQuotaTests-\(UUID().uuidString)"))
        var quota = OnlineQuota()
        quota.record(12.5, on: day1)
        OnlineQuotaStore.save(quota, to: defaults)
        #expect(OnlineQuotaStore.load(from: defaults) == quota.current(on: day1))
        #expect(OnlineQuotaStore.load(from: UserDefaults(suiteName: "OnlineQuotaTests-empty-\(UUID().uuidString)")!) == OnlineQuota())
    }
}

struct OnlineConfigTests {
    private func bundle(containing text: String?) throws -> Bundle {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let text {
            try text.write(to: folder.appendingPathComponent("spoonacular.key"), atomically: true, encoding: .utf8)
        }
        return try #require(Bundle(url: folder))
    }

    @Test func theKeyIsReadFromItsFileAndTrimmed() throws {
        #expect(OnlineRecipeConfig.key(in: try bundle(containing: "  abc123\n")) == "abc123")
    }

    @Test func noFileOrAnEmptyOneMeansNoKey() throws {
        #expect(OnlineRecipeConfig.key(in: try bundle(containing: nil)) == nil)
        #expect(OnlineRecipeConfig.key(in: try bundle(containing: " \n")) == nil)
    }
}

struct OnlineOnboardingTests {
    @Test func theQuestionComesRightAfterTheFirstRecipe() {
        #expect(OnboardingStep.recipes.next(showsNutrition: true, offersOnline: true) == .online)
        #expect(OnboardingStep.online.next(showsNutrition: true, offersOnline: true) == .health)
        #expect(OnboardingStep.health.previous(showsNutrition: true, offersOnline: true) == .online)
        #expect(OnboardingStep.online.previous(showsNutrition: true, offersOnline: true) == .recipes)
        #expect(OnboardingStep.online.showsProgress)
    }

    @Test func withoutAWayToLookThemUpItIsSkippedBothWays() {
        #expect(OnboardingStep.recipes.next(showsNutrition: true, offersOnline: false) == .health)
        #expect(OnboardingStep.health.previous(showsNutrition: true, offersOnline: false) == .recipes)
        // Off is the default, so the older calls keep working.
        #expect(OnboardingStep.recipes.next(showsNutrition: true) == .health)
    }

    @Test func skippingBothGoesStraightToTheCommitment() {
        #expect(OnboardingStep.recipes.next(showsNutrition: false, offersOnline: false) == .commitment)
        #expect(OnboardingStep.commitment.previous(showsNutrition: false, offersOnline: false) == .recipes)
    }

    @Test func peopleWhoChoseJustCookStillGetTheQuestion() {
        #expect(OnboardingStep.recipes.next(showsNutrition: false, offersOnline: true) == .online)
        #expect(OnboardingStep.online.next(showsNutrition: false, offersOnline: true) == .commitment)
        #expect(OnboardingStep.commitment.previous(showsNutrition: false, offersOnline: true) == .online)
    }

    @Test func theEndsOfTheFlowAreUnchanged() {
        #expect(OnboardingStep.welcome.previous(showsNutrition: true, offersOnline: true) == nil)
        #expect(OnboardingStep.allSet.next(showsNutrition: true, offersOnline: true) == nil)
    }
}
