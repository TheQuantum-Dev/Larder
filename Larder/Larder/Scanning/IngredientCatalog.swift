//
//  IngredientCatalog.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation

/// The bundled ingredient list plus the matching that turns free text (a
/// model's guess, a classifier label, text read off a label) into one of them.
nonisolated enum IngredientCatalog {

    // MARK: - Matching

    /// Turns text into a comparable form: lowercase, letters only, each word
    /// made singular. "Purple Onions!" and "purple onion" give the same key.
    static func key(for text: String) -> String {
        let letters = text.lowercased().map { $0.isLetter ? $0 : " " }
        return String(letters)
            .split(separator: " ")
            .map { singular(String($0)) }
            .joined(separator: " ")
    }

    private static func singular(_ word: String) -> String {
        guard word.count > 3 else { return word }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("oes") { return String(word.dropLast(2)) }
        if ["ches", "shes", "xes", "sses", "zes"].contains(where: word.hasSuffix) { return String(word.dropLast(2)) }
        if word.hasSuffix("ss") || word.hasSuffix("us") || word.hasSuffix("is") { return word }
        if word.hasSuffix("s") { return String(word.dropLast()) }
        return word
    }

    /// Words that show up in model answers but aren't food.
    private static let notFood: Set<String> = [
        "container", "bottle", "jar", "box", "bag", "package", "shelf", "drawer", "fridge",
        "refrigerator", "thermometer", "lid", "tray", "bowl", "plate", "food", "item", "drink",
        "packaging", "can", "carton", "leftover", "glass", "plastic", "cardboard", "paper",
        "metal", "wooden", "empty",
    ]

    /// Words too vague to be an item on their own. A model answering "fruit"
    /// or "sauce" hasn't told us what's in the fridge.
    private static let tooGeneric: Set<String> = [
        "fruit", "vegetable", "veggie", "produce", "sauce", "condiment", "dairy", "meat",
        "snack", "beverage", "ingredient", "grocery", "white", "yellow", "red", "green", "brown",
        "black", "blue", "purple", "pink", "liquid",
    ]

    private static let index: [String: Ingredient] = {
        var result: [String: Ingredient] = [:]
        for ingredient in all {
            for name in [ingredient.id, ingredient.name] + ingredient.aliases {
                result[key(for: name)] = ingredient
            }
        }
        return result
    }()

    /// Aliases longest first, so "peanut butter" is found before "butter".
    private static let phrases: [(key: String, ingredient: Ingredient)] =
        index.map { ($0.key, $0.value) }.sorted { $0.key.count > $1.key.count }

    /// Maps a name to a catalog ingredient, or to a custom item if it isn't
    /// one. Returns nil for empty text and for things that aren't food.
    static func resolve(_ name: String) -> ResolvedItem? {
        var words = key(for: name).split(separator: " ").map(String.init)
        // "milk carton" is milk, and "glass jar" is nothing: drop trailing
        // container words before deciding.
        while let last = words.last, notFood.contains(last) { words.removeLast() }
        let trimmed = words.joined(separator: " ")
        guard !trimmed.isEmpty, trimmed.count <= 40 else { return nil }

        if let hit = index[trimmed] { return ResolvedItem(hit) }
        // "purple onion" -> "onion", "whole milk" -> "milk".
        for length in stride(from: min(words.count, 3) - 1, through: 1, by: -1) {
            if let hit = index[words.suffix(length).joined(separator: " ")] { return ResolvedItem(hit) }
        }
        if tooGeneric.contains(trimmed) { return nil }
        return ResolvedItem(customName: trimmed)
    }

    /// Ingredients named anywhere inside a block of text.
    static func find(inText text: String) -> Set<ResolvedItem> {
        var remaining = " " + key(for: text) + " "
        var found: Set<ResolvedItem> = []
        for (phrase, ingredient) in phrases {
            let needle = " " + phrase + " "
            if remaining.contains(needle) {
                found.insert(ResolvedItem(ingredient))
                remaining = remaining.replacingOccurrences(of: needle, with: " ")
            }
        }
        return found
    }

    /// For the manual-entry search box.
    static func search(_ query: String) -> [Ingredient] {
        let q = key(for: query)
        guard !q.isEmpty else { return [] }
        return all.filter { ingredient in
            ([ingredient.name] + ingredient.aliases).contains { key(for: $0).hasPrefix(q) || key(for: $0).contains(" " + q) }
        }
    }

    /// The quick-add grid: things a student kitchen usually has.
    static let quickAdd: [Ingredient] = [
        "egg", "milk", "bread", "rice", "pasta", "chicken", "cheese", "butter",
        "onion", "tomato", "potato", "banana", "apple", "carrot", "garlic", "beans",
        "peanut-butter", "ramen", "yogurt", "lettuce", "tortilla", "oats", "olive-oil", "salt",
    ].compactMap { id in all.first { $0.id == id } }

    // MARK: - Data

    private static func item(_ id: String, _ name: String, _ emoji: String,
                             _ category: IngredientCategory, _ aliases: String...) -> Ingredient {
        Ingredient(id: id, name: name, emoji: emoji, category: category, aliases: aliases)
    }

    static let all: [Ingredient] = [
        // Produce
        item("apple", "Apples", "🍎", .produce, "apple"),
        item("banana", "Bananas", "🍌", .produce, "banana"),
        item("orange", "Oranges", "🍊", .produce, "orange", "clementine", "tangerine", "mandarin"),
        item("lemon", "Lemons", "🍋", .produce, "lemon"),
        item("lime", "Limes", "🍋‍🟩", .produce, "lime"),
        item("grape", "Grapes", "🍇", .produce, "grape"),
        item("strawberry", "Strawberries", "🍓", .produce, "strawberry"),
        item("blueberry", "Blueberries", "🫐", .produce, "blueberry"),
        item("pear", "Pears", "🍐", .produce, "pear"),
        item("peach", "Peaches", "🍑", .produce, "peach", "nectarine"),
        item("pineapple", "Pineapple", "🍍", .produce, "pineapple"),
        item("watermelon", "Watermelon", "🍉", .produce, "watermelon", "melon", "cantaloupe"),
        item("mango", "Mango", "🥭", .produce, "mango"),
        item("cherry", "Cherries", "🍒", .produce, "cherry"),
        item("avocado", "Avocados", "🥑", .produce, "avocado"),
        item("tomato", "Tomatoes", "🍅", .produce, "tomato", "cherry tomato", "roma tomato"),
        item("potato", "Potatoes", "🥔", .produce, "potato", "russet potato", "baby potato"),
        item("sweet-potato", "Sweet potatoes", "🍠", .produce, "sweet potato", "yam"),
        item("onion", "Onions", "🧅", .produce, "onion", "red onion", "purple onion", "yellow onion", "green onion", "scallion", "shallot"),
        item("garlic", "Garlic", "🧄", .produce, "garlic"),
        item("carrot", "Carrots", "🥕", .produce, "carrot"),
        item("broccoli", "Broccoli", "🥦", .produce, "broccoli", "cauliflower"),
        item("lettuce", "Lettuce and greens", "🥬", .produce, "lettuce", "salad", "salad greens", "mixed greens", "romaine", "arugula"),
        item("spinach", "Spinach", "🥬", .produce, "spinach"),
        item("kale", "Kale", "🥬", .produce, "kale"),
        item("cabbage", "Cabbage", "🥬", .produce, "cabbage", "coleslaw"),
        item("celery", "Celery", "🥬", .produce, "celery"),
        item("cucumber", "Cucumbers", "🥒", .produce, "cucumber"),
        item("zucchini", "Zucchini", "🥒", .produce, "zucchini", "squash"),
        item("bell-pepper", "Bell peppers", "🫑", .produce, "bell pepper", "pepper", "capsicum"),
        item("jalapeno", "Jalapeños", "🌶️", .produce, "jalapeno", "jalapeño", "chili pepper", "chile"),
        item("corn", "Corn", "🌽", .produce, "corn", "corn on the cob", "sweet corn"),
        item("mushroom", "Mushrooms", "🍄", .produce, "mushroom"),
        item("green-bean", "Green beans", "🫛", .produce, "green bean", "string bean", "asparagus"),
        item("peas", "Peas", "🫛", .produce, "pea", "snow pea", "snap pea"),
        item("ginger", "Ginger", "🫚", .produce, "ginger"),
        item("herbs", "Fresh herbs", "🌿", .produce, "herb", "cilantro", "parsley", "basil", "mint", "dill", "rosemary", "thyme"),
        // Dairy and eggs
        item("egg", "Eggs", "🥚", .dairyAndEggs, "egg"),
        item("milk", "Milk", "🥛", .dairyAndEggs, "milk", "whole milk", "skim milk", "oat milk", "almond milk"),
        item("butter", "Butter", "🧈", .dairyAndEggs, "butter", "margarine"),
        item("cheese", "Cheese", "🧀", .dairyAndEggs, "cheese", "cheddar", "mozzarella", "parmesan", "swiss", "cheese slice", "shredded cheese", "cream cheese"),
        item("yogurt", "Yogurt", "🥣", .dairyAndEggs, "yogurt", "yoghurt", "greek yogurt"),
        item("sour-cream", "Sour cream", "🥣", .dairyAndEggs, "sour cream", "cream"),
        // Protein
        item("chicken", "Chicken", "🍗", .protein, "chicken", "chicken breast", "chicken thigh", "fried chicken", "rotisserie chicken", "poultry"),
        item("beef", "Beef", "🥩", .protein, "beef", "ground beef", "steak", "burger"),
        item("pork", "Pork", "🥩", .protein, "pork", "pork chop"),
        item("bacon", "Bacon", "🥓", .protein, "bacon"),
        item("sausage", "Sausage", "🌭", .protein, "sausage", "hot dog", "salami"),
        item("ham", "Ham", "🍖", .protein, "ham", "deli meat", "lunch meat"),
        item("turkey", "Turkey", "🦃", .protein, "turkey"),
        item("fish", "Fish", "🐟", .protein, "fish", "salmon", "tilapia", "cod"),
        item("shrimp", "Shrimp", "🦐", .protein, "shrimp", "prawn"),
        item("tofu", "Tofu", "🥡", .protein, "tofu", "tempeh"),
        item("beans", "Beans", "🫘", .protein, "bean", "black bean", "kidney bean", "pinto bean", "chickpea", "garbanzo", "baked bean"),
        item("lentils", "Lentils", "🫘", .protein, "lentil"),
        item("peanut-butter", "Peanut butter", "🥜", .protein, "peanut butter", "almond butter", "nut butter"),
        item("nuts", "Nuts", "🥜", .protein, "nut", "almond", "walnut", "cashew", "peanut", "pecan", "trail mix"),
        // Grains
        item("rice", "Rice", "🍚", .grains, "rice", "brown rice", "white rice"),
        item("pasta", "Pasta", "🍝", .grains, "pasta", "spaghetti", "penne", "macaroni", "noodle", "fettuccine"),
        item("ramen", "Instant noodles", "🍜", .grains, "ramen", "instant noodle", "cup noodle"),
        item("bread", "Bread", "🍞", .grains, "bread", "loaf", "sandwich bread", "bun", "roll", "toast", "sourdough"),
        item("tortilla", "Tortillas", "🫓", .grains, "tortilla", "flatbread", "pita", "wrap", "naan"),
        item("bagel", "Bagels", "🥯", .grains, "bagel", "english muffin", "muffin"),
        item("oats", "Oats", "🥣", .grains, "oat", "oatmeal", "rolled oat"),
        item("cereal", "Cereal", "🥣", .grains, "cereal", "granola", "corn flake"),
        item("flour", "Flour", "🌾", .grains, "flour", "baking mix", "pancake mix"),
        item("quinoa", "Quinoa and couscous", "🌾", .grains, "quinoa", "couscous", "barley"),
        item("crackers", "Crackers", "🍘", .grains, "cracker", "pretzel", "rice cake"),
        // Pantry
        item("olive-oil", "Olive oil", "🫒", .pantry, "olive oil"),
        item("cooking-oil", "Cooking oil", "🛢️", .pantry, "cooking oil", "vegetable oil", "canola oil", "oil"),
        item("salt", "Salt", "🧂", .pantry, "salt"),
        item("black-pepper", "Black pepper", "🧂", .pantry, "black pepper", "pepper shaker", "spice", "seasoning"),
        item("sugar", "Sugar", "🍬", .pantry, "sugar", "brown sugar", "sweetener"),
        item("honey", "Honey", "🍯", .pantry, "honey", "maple syrup", "syrup"),
        item("ketchup", "Ketchup", "🥫", .pantry, "ketchup", "catsup"),
        item("mustard", "Mustard", "🟡", .pantry, "mustard"),
        item("mayo", "Mayonnaise", "🥄", .pantry, "mayo", "mayonnaise", "crema"),
        item("soy-sauce", "Soy sauce", "🍶", .pantry, "soy sauce", "teriyaki", "sriracha", "hot sauce"),
        item("salsa", "Salsa", "🥫", .pantry, "salsa", "pico de gallo"),
        item("tomato-sauce", "Tomato sauce", "🥫", .pantry, "tomato sauce", "pasta sauce", "marinara", "canned tomato", "tomato paste"),
        item("canned-tuna", "Canned tuna", "🐟", .pantry, "tuna", "canned tuna", "sardine"),
        item("broth", "Broth", "🍲", .pantry, "broth", "stock", "bouillon", "soup"),
        item("vinegar", "Vinegar", "🍶", .pantry, "vinegar"),
        item("jam", "Jam", "🫙", .pantry, "jam", "jelly", "preserve", "marmalade"),
        item("olives", "Olives", "🫒", .pantry, "olive", "caper"),
        item("pickles", "Pickles", "🥒", .pantry, "pickle", "relish", "sauerkraut"),
        item("dressing", "Salad dressing", "🥗", .pantry, "dressing", "salad dressing", "ranch", "vinaigrette"),
        item("hummus", "Hummus", "🥣", .pantry, "hummus", "dip", "guacamole"),
        item("chocolate", "Chocolate", "🍫", .pantry, "chocolate", "cocoa"),
        // Drinks
        item("juice", "Juice", "🧃", .drinks, "juice", "orange juice", "apple juice"),
        item("soda", "Soda", "🥤", .drinks, "soda", "cola", "coke", "energy drink"),
        item("water", "Water", "💧", .drinks, "water", "bottled water", "sparkling water"),
        item("coffee", "Coffee", "☕", .drinks, "coffee", "espresso"),
        item("tea", "Tea", "🍵", .drinks, "tea"),
        // Snacks and frozen
        item("chips", "Chips", "🍟", .snacks, "chip", "potato chip", "crisp", "tortilla chip"),
        item("popcorn", "Popcorn", "🍿", .snacks, "popcorn"),
        item("cookies", "Cookies", "🍪", .snacks, "cookie", "biscuit", "cake", "brownie"),
        item("granola-bar", "Snack bars", "🍫", .snacks, "granola bar", "snack bar", "protein bar", "cereal bar"),
        item("ice-cream", "Ice cream", "🍨", .snacks, "ice cream", "popsicle", "frozen dessert"),
        item("frozen-veg", "Frozen vegetables", "🧊", .snacks, "frozen vegetable", "frozen veggie"),
        item("pizza", "Pizza", "🍕", .snacks, "pizza", "frozen pizza"),
    ]
}
