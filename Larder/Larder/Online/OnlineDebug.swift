//
//  OnlineDebug.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

#if DEBUG
import Foundation

/// A stand-in for the recipe service, for debug builds: a handful of made-up
/// sample recipes in the same shape the real service uses, so the whole
/// online path can be tried without a key or a network.
///
/// `-fakeOnline YES` turns it on. `-fakeOnlineState offline|exhausted|failed|empty`
/// makes it answer that way instead, to see how the screens cope.
nonisolated struct FakeRecipeAPI: RecipeAPI {
    func search(_ request: OnlineRequest) async throws -> OnlineSearchOutcome {
        try await Task.sleep(for: .milliseconds(500))
        switch UserDefaults.standard.string(forKey: "fakeOnlineState") {
        case "offline": throw OnlineError.offline
        case "exhausted": throw OnlineError.quotaExceeded
        case "failed": throw OnlineError.badResponse
        case "empty": return OnlineSearchOutcome(recipes: [], pointsCharged: 1)
        default: break
        }
        let response = try JSONDecoder().decode(OnlineSearchResponse.self, from: Data(Self.sampleJSON.utf8))
        return OnlineSearchOutcome(recipes: response.results, pointsCharged: 2.6)
    }

    func recipe(id: Int) async throws -> OnlineRecipeDTO {
        let response = try JSONDecoder().decode(OnlineSearchResponse.self, from: Data(Self.sampleJSON.utf8))
        guard let recipe = response.results.first(where: { $0.id == id }) else { throw OnlineError.badResponse }
        return recipe
    }

    static let sampleJSON = #"""
    {"results": [
      {"id": 900001, "title": "Sesame chicken rice bowl", "servings": 2, "readyInMinutes": 25, "pricePerServing": 215.0,
       "sourceName": "Weeknight Bowls", "sourceUrl": "https://example.com/sesame-chicken-rice-bowl",
       "vegetarian": false, "vegan": false, "glutenFree": false, "dairyFree": true, "veryHealthy": true,
       "dishTypes": ["lunch", "main course", "dinner"],
       "extendedIngredients": [
         {"nameClean": "chicken breast", "original": "2 chicken breasts, sliced thin", "amount": 2, "unit": ""},
         {"nameClean": "rice", "original": "1 cup cooked rice", "amount": 1, "unit": "cup"},
         {"nameClean": "broccoli", "original": "2 cups broccoli florets", "amount": 2, "unit": "cups"},
         {"nameClean": "soy sauce", "original": "2 tbsp soy sauce", "amount": 2, "unit": "tbsp"},
         {"nameClean": "garlic", "original": "2 garlic cloves, minced", "amount": 2, "unit": "cloves"},
         {"nameClean": "sesame seeds", "original": "1 tbsp sesame seeds", "amount": 1, "unit": "tbsp"}],
       "analyzedInstructions": [{"name": "", "steps": [
         {"number": 1, "step": "Stir the soy sauce and garlic together in a bowl and toss the sliced chicken in it.", "equipment": [{"name": "bowl"}]},
         {"number": 2, "step": "Cook the chicken in a hot pan for 6 minutes, turning once, until it is cooked all the way through.", "equipment": [{"name": "frying pan"}], "length": {"number": 6, "unit": "minutes"}},
         {"number": 3, "step": "Add the broccoli and a splash of water, cover, and steam for 4 minutes.", "equipment": [{"name": "frying pan"}], "length": {"number": 4, "unit": "minutes"}},
         {"number": 4, "step": "Spoon over the rice and sprinkle with sesame seeds.", "equipment": []}]}],
       "nutrition": {"nutrients": [
         {"name": "Calories", "amount": 560, "unit": "kcal"}, {"name": "Protein", "amount": 44, "unit": "g"},
         {"name": "Carbohydrates", "amount": 52, "unit": "g"}, {"name": "Fat", "amount": 16, "unit": "g"}]}},
      {"id": 900002, "title": "Cheesy spinach egg wrap", "servings": 1, "readyInMinutes": 10, "pricePerServing": 150.0,
       "sourceName": "Morning Table", "sourceUrl": "https://example.com/cheesy-spinach-egg-wrap",
       "vegetarian": true, "vegan": false, "glutenFree": false, "dairyFree": false, "veryHealthy": false,
       "dishTypes": ["breakfast", "brunch"],
       "extendedIngredients": [
         {"nameClean": "egg", "original": "3 eggs", "amount": 3, "unit": ""},
         {"nameClean": "tortilla", "original": "1 large flour tortilla", "amount": 1, "unit": ""},
         {"nameClean": "spinach", "original": "a handful of baby spinach", "amount": 1, "unit": "handful"},
         {"nameClean": "cheddar cheese", "original": "1/4 cup shredded cheddar", "amount": 0.25, "unit": "cup"}],
       "analyzedInstructions": [{"name": "", "steps": [
         {"number": 1, "step": "Scramble the eggs in a pan over medium heat for 3 minutes until they are completely set.", "equipment": [{"name": "frying pan"}], "length": {"number": 3, "unit": "minutes"}},
         {"number": 2, "step": "Stir in the spinach until it wilts, then take the pan off the heat.", "equipment": []},
         {"number": 3, "step": "Fill the tortilla with the eggs, sprinkle on the cheese, and roll it up.", "equipment": []}]}],
       "nutrition": {"nutrients": [
         {"name": "Calories", "amount": 430, "unit": "kcal"}, {"name": "Protein", "amount": 30, "unit": "g"},
         {"name": "Carbohydrates", "amount": 28, "unit": "g"}, {"name": "Fat", "amount": 22, "unit": "g"}]}},
      {"id": 900003, "title": "Tuna tomato pasta bake", "servings": 3, "readyInMinutes": 35, "pricePerServing": 190.0,
       "sourceName": "Pantry Suppers", "sourceUrl": "https://example.com/tuna-tomato-pasta-bake",
       "vegetarian": false, "vegan": false, "glutenFree": false, "dairyFree": false, "veryHealthy": false,
       "dishTypes": ["main course", "dinner"],
       "extendedIngredients": [
         {"nameClean": "pasta", "original": "200 g dry pasta", "amount": 200, "unit": "g"},
         {"nameClean": "canned tuna", "original": "2 cans tuna, drained", "amount": 2, "unit": "cans"},
         {"nameClean": "tomato sauce", "original": "1 jar tomato pasta sauce", "amount": 1, "unit": "jar"},
         {"nameClean": "mozzarella cheese", "original": "1 cup shredded mozzarella", "amount": 1, "unit": "cup"},
         {"nameClean": "onion", "original": "1 small onion, diced", "amount": 1, "unit": ""}],
       "analyzedInstructions": [{"name": "", "steps": [
         {"number": 1, "step": "Boil the pasta for 9 minutes, then drain.", "equipment": [{"name": "pot"}], "length": {"number": 9, "unit": "minutes"}},
         {"number": 2, "step": "Mix the pasta with the tuna, sauce and onion and tip it into a baking dish.", "equipment": [{"name": "baking dish"}]},
         {"number": 3, "step": "Top with the cheese and bake at 400°F (200°C) for 15 minutes until bubbling.", "equipment": [{"name": "oven"}], "length": {"number": 15, "unit": "minutes"}}]}],
       "nutrition": {"nutrients": [
         {"name": "Calories", "amount": 610, "unit": "kcal"}, {"name": "Protein", "amount": 38, "unit": "g"},
         {"name": "Carbohydrates", "amount": 62, "unit": "g"}, {"name": "Fat", "amount": 20, "unit": "g"}]}},
      {"id": 900004, "title": "Greek yogurt banana oat bowl", "servings": 1, "readyInMinutes": 5, "pricePerServing": 120.0,
       "sourceName": "Easy Breakfasts", "sourceUrl": "https://example.com/yogurt-banana-oat-bowl",
       "vegetarian": true, "vegan": false, "glutenFree": false, "dairyFree": false, "veryHealthy": true,
       "dishTypes": ["breakfast"],
       "extendedIngredients": [
         {"nameClean": "greek yogurt", "original": "3/4 cup plain Greek yogurt", "amount": 0.75, "unit": "cup"},
         {"nameClean": "banana", "original": "1 ripe banana, sliced", "amount": 1, "unit": ""},
         {"nameClean": "rolled oats", "original": "1/4 cup rolled oats", "amount": 0.25, "unit": "cup"},
         {"nameClean": "honey", "original": "1 tsp honey", "amount": 1, "unit": "tsp"},
         {"nameClean": "cinnamon", "original": "a pinch of ground cinnamon", "amount": 1, "unit": "pinch"}],
       "analyzedInstructions": [{"name": "", "steps": [
         {"number": 1, "step": "Spoon the yogurt into a bowl and top with the banana and oats.", "equipment": [{"name": "bowl"}]},
         {"number": 2, "step": "Drizzle with honey and finish with a pinch of cinnamon.", "equipment": []}]}],
       "nutrition": {"nutrients": [
         {"name": "Calories", "amount": 380, "unit": "kcal"}, {"name": "Protein", "amount": 26, "unit": "g"},
         {"name": "Carbohydrates", "amount": 58, "unit": "g"}, {"name": "Fat", "amount": 6, "unit": "g"}]}},
      {"id": 900005, "title": "Smoky beef and bean chili", "servings": 4, "readyInMinutes": 40, "pricePerServing": 260.0,
       "sourceName": "Slow Pot Kitchen", "sourceUrl": "https://example.com/smoky-beef-bean-chili",
       "vegetarian": false, "vegan": false, "glutenFree": true, "dairyFree": true, "veryHealthy": false,
       "dishTypes": ["main course", "dinner"],
       "extendedIngredients": [
         {"nameClean": "ground beef", "original": "1 lb lean ground beef", "amount": 1, "unit": "lb"},
         {"nameClean": "kidney beans", "original": "1 can kidney beans, drained", "amount": 1, "unit": "can"},
         {"nameClean": "onion", "original": "1 onion, chopped", "amount": 1, "unit": ""},
         {"nameClean": "tomato sauce", "original": "1 can tomato sauce", "amount": 1, "unit": "can"},
         {"nameClean": "chili powder", "original": "2 tbsp chili powder", "amount": 2, "unit": "tbsp"},
         {"nameClean": "cumin", "original": "1 tsp ground cumin", "amount": 1, "unit": "tsp"}],
       "analyzedInstructions": [{"name": "", "steps": [
         {"number": 1, "step": "Brown the beef with the onion in a large pot, breaking it up, for 8 minutes until no pink is left.", "equipment": [{"name": "pot"}], "length": {"number": 8, "unit": "minutes"}},
         {"number": 2, "step": "Stir in the tomato sauce, beans and spices and simmer for 25 minutes.", "equipment": [{"name": "pot"}], "length": {"number": 25, "unit": "minutes"}}]}],
       "nutrition": {"nutrients": [
         {"name": "Calories", "amount": 520, "unit": "kcal"}, {"name": "Protein", "amount": 41, "unit": "g"},
         {"name": "Carbohydrates", "amount": 38, "unit": "g"}, {"name": "Fat", "amount": 22, "unit": "g"}]}},
      {"id": 900006, "title": "Garam masala chickpea stew", "servings": 3, "readyInMinutes": 30, "pricePerServing": 175.0,
       "sourceName": "Green Plate", "sourceUrl": "https://example.com/garam-masala-chickpea-stew",
       "vegetarian": true, "vegan": true, "glutenFree": true, "dairyFree": true, "veryHealthy": true,
       "dishTypes": ["main course", "dinner", "soup"],
       "extendedIngredients": [
         {"nameClean": "chickpeas", "original": "2 cans chickpeas, drained", "amount": 2, "unit": "cans"},
         {"nameClean": "onion", "original": "1 onion, diced", "amount": 1, "unit": ""},
         {"nameClean": "tomato sauce", "original": "1 cup tomato sauce", "amount": 1, "unit": "cup"},
         {"nameClean": "garam masala", "original": "2 tsp garam masala", "amount": 2, "unit": "tsp"},
         {"nameClean": "coconut milk", "original": "1 can coconut milk", "amount": 1, "unit": "can"}],
       "analyzedInstructions": [{"name": "", "steps": [
         {"number": 1, "step": "Soften the onion in a pot for 5 minutes.", "equipment": [{"name": "pot"}], "length": {"number": 5, "unit": "minutes"}},
         {"number": 2, "step": "Add the chickpeas, tomato sauce, coconut milk and garam masala and simmer for 15 minutes.", "equipment": [{"name": "pot"}], "length": {"number": 15, "unit": "minutes"}}]}],
       "nutrition": {"nutrients": [
         {"name": "Calories", "amount": 480, "unit": "kcal"}, {"name": "Protein", "amount": 19, "unit": "g"},
         {"name": "Carbohydrates", "amount": 54, "unit": "g"}, {"name": "Fat", "amount": 20, "unit": "g"}]}}
    ]}
    """#
}
#endif
