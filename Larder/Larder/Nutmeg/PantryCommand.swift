//
//  PantryCommand.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import Foundation

/// A change to the pantry asked for in the chat: "add 6 eggs and 2 cans of
/// beans", "I only have 2 eggs left", "I ran out of milk". It's worked out
/// with plain rules, never guessed by a model, and it's only ever a proposal:
/// the chat shows it as a card, and nothing changes until the person taps.
nonisolated struct PantryCommand: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        /// Bought or found more.
        case add
        /// This is how much there is now.
        case set
        /// All gone.
        case remove
    }

    struct Line: Equatable, Sendable {
        let item: ResolvedItem
        var quantity: Double?
        var unit: PantryUnit?
        let action: Action
    }

    var lines: [Line]

    // MARK: - Reading a message

    private static let removePhrases = ["ran out of", "run out of", "out of", "used up", "used the last", "finished the",
                                        "finished off", "finished my", "no more", "remove", "take off", "take out",
                                        "delete", "all gone", "gone", "none left", "threw out", "threw away"]
    /// "How much there is now", when a number comes with them.
    private static let setPhrases = ["i have", "i ve got", "i still have", "there are", "we have", "we ve got"]
    /// "More of it", said outright.
    private static let addPhrases = ["add", "put", "bought", "picked up", "grabbed", "restock", "stock", "stocked"]
    /// A question is a question, even when it mentions an amount.
    private static let questionWords = ["what", "can i", "could i", "should i", "how", "recipe", "idea", "ideas", "make",
                                        "cook", "which", "why", "do i have"]

    /// Nil when the message isn't asking to change the pantry.
    static func parse(_ message: String) -> PantryCommand? {
        let text = " " + normalised(message) + " "
        let isQuestion = message.contains("?") || has(text, questionWords)
        let action: Action
        if has(text, removePhrases) {
            action = .remove
        } else if has(text, addPhrases) {
            action = .add
        } else if has(text, ["only have", "only got", "down to"])
                    || (containsNumber(text) && (has(text, ["left"]) || (has(text, setPhrases) && !isQuestion))) {
            // "I have 6 eggs" is how many there are; "I have eggs, what can I make?" is a question.
            action = .set
        } else if has(text, ["got", "just got"]), containsNumber(text), !isQuestion {
            // "I got 6 eggs" means more of them.
            action = .add
        } else {
            return nil
        }
        // "How many eggs have I got left?" is a question, whatever the verb.
        if isQuestion, action != .remove, !has(text, ["add", "put", "remove", "update"]) { return nil }

        var lines: [Line] = []
        for segment in segments(of: normalised(message)) {
            let found = IngredientCatalog.find(inText: segment).sorted { $0.name.count > $1.name.count }
            guard let item = found.first ?? customItem(in: segment, when: action) else { continue }
            guard !lines.contains(where: { $0.item == item }) else { continue }
            let (quantity, unit) = amount(in: segment)
            lines.append(Line(item: item, quantity: action == .remove ? nil : quantity,
                              unit: action == .remove ? nil : unit, action: action))
        }
        // "I have some eggs left" says nothing to update.
        if action == .set { lines.removeAll { $0.quantity == nil } }
        return lines.isEmpty ? nil : PantryCommand(lines: lines)
    }

    private static func normalised(_ message: String) -> String {
        message.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "'", with: " ")
            .map { $0.isLetter || $0.isNumber || $0 == "." || $0 == "," || $0 == "&" ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
    }

    private static func has(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains { text.contains(" " + $0 + " ") }
    }

    private static func containsNumber(_ text: String) -> Bool {
        text.split(separator: " ").contains { number(String($0)) != nil }
    }

    /// "6 eggs, 2 cans of beans and some rice" → one piece per item.
    private static func segments(of text: String) -> [String] {
        var pieces = [text]
        for separator in [",", " and ", " & ", " plus ", " with "] {
            pieces = pieces.flatMap { $0.components(separatedBy: separator) }
        }
        return pieces.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static let numberWords: [String: Double] = [
        "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
        "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "dozen": 12, "half": 0.5, "couple": 2,
    ]

    private static func number(_ word: String) -> Double? {
        if let value = Double(word), value >= 0, value < 10_000 { return value }
        return numberWords[word]
    }

    private static let unitWords: [String: PantryUnit] = [
        "can": .cans, "cans": .cans, "tin": .cans, "tins": .cans,
        "bag": .bags, "bags": .bags,
        "pack": .packs, "packs": .packs, "packet": .packs, "packets": .packs, "box": .packs, "boxes": .packs,
        "bottle": .bottles, "bottles": .bottles, "carton": .bottles, "cartons": .bottles, "jug": .bottles, "jar": .bottles,
        "jars": .bottles,
        "g": .grams, "gram": .grams, "grams": .grams, "kg": .kilograms, "kilo": .kilograms, "kilos": .kilograms,
        "ml": .millilitres, "l": .litres, "litre": .litres, "litres": .litres, "liter": .litres, "liters": .litres,
    ]

    /// The first amount in a piece, and its unit if one follows: "2 cans of
    /// beans" is 2 cans, "500g rice" is 500 g, "a dozen eggs" is 12.
    private static func amount(in segment: String) -> (Double?, PantryUnit?) {
        var words = segment.split(separator: " ").map(String.init)
        // "500g" and "1.5l" come as one word; split the number from the unit.
        words = words.flatMap { word -> [String] in
            guard let split = word.firstIndex(where: \.isLetter), split > word.startIndex,
                  Double(word[..<split]) != nil, unitWords[String(word[split...])] != nil else { return [word] }
            return [String(word[..<split]), String(word[split...])]
        }
        for (index, word) in words.enumerated() {
            guard var value = number(word) else { continue }
            var next = index + 1
            // "a dozen", "half a", "a couple of".
            if next < words.count, let following = number(words[next]), word == "a" || word == "an" || word == "half" {
                value = word == "half" ? 0.5 : following
                next += 1
            }
            // "a lot of", "a few", "a bit of" aren't amounts.
            if word == "a" || word == "an", next < words.count,
               ["lot", "lots", "few", "bit", "little", "bunch", "load"].contains(words[next]) { return (nil, nil) }
            let unit = next < words.count ? unitWords[words[next]] : nil
            return (value, unit)
        }
        return (nil, nil)
    }

    /// Something not in the catalog, named after "add": "add 2 jars of kimchi".
    private static func customItem(in segment: String, when action: Action) -> ResolvedItem? {
        guard action == .add else { return nil }
        let filler: Set<String> = ["add", "put", "bought", "got", "i", "have", "ve", "some", "of", "the", "my", "to",
                                   "in", "pantry", "please", "just", "also", "more", "new", "picked", "up", "grabbed"]
        let words = segment.split(separator: " ").map(String.init)
            .filter { !filler.contains($0) && number($0) == nil && unitWords[$0] == nil && Double($0) == nil }
        guard !words.isEmpty, words.count <= 3 else { return nil }
        return IngredientCatalog.resolve(words.joined(separator: " "))
    }
}
