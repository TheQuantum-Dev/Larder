//
//  PantryCommandTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/27/26.
//

import Foundation
import Testing
@testable import Larder

struct PantryCommandTests {
    private func lines(_ message: String) -> [PantryCommand.Line] {
        PantryCommand.parse(message)?.lines ?? []
    }

    private func summary(_ message: String) -> [String] {
        lines(message).map { line in
            let amount = line.quantity.map { " \($0.formatted())" } ?? ""
            let unit = line.unit.map { " \($0.rawValue)" } ?? ""
            return "\(line.action) \(line.item.id)\(amount)\(unit)"
        }
    }

    @Test func addingWithAmountsAndUnits() {
        #expect(summary("add 6 eggs and 2 cans of beans") == ["add egg 6", "add beans 2 cans"])
        #expect(summary("Add a bag of rice, some milk & a dozen eggs") == ["add rice 1 bags", "add milk", "add egg 12"])
        #expect(summary("I bought 500g chicken") == ["add chicken 500 g"])
        #expect(summary("put two bottles of milk in my pantry") == ["add milk 2 bottles"])
        #expect(summary("I just got 3 bananas") == ["add banana 3"])
    }

    @Test func sayingHowMuchIsLeft() {
        #expect(summary("I only have 2 eggs left") == ["set egg 2"])
        #expect(summary("I have 6 eggs") == ["set egg 6"])
        #expect(summary("down to one can of tuna") == ["set canned-tuna 1 cans"])
    }

    @Test func somethingRanOut() {
        #expect(summary("I ran out of milk") == ["remove milk"])
        #expect(summary("used up the rice and the eggs") == ["remove rice", "remove egg"])
        #expect(summary("no more bread") == ["remove bread"])
        #expect(summary("remove 2 eggs") == ["remove egg"])
    }

    @Test func questionsAreNotCommands() {
        #expect(PantryCommand.parse("What can I make with eggs?") == nil)
        #expect(PantryCommand.parse("I have 6 eggs, what can I make?") == nil)
        #expect(PantryCommand.parse("do i have milk") == nil)
        #expect(PantryCommand.parse("How many eggs have I got left?") == nil)
        #expect(PantryCommand.parse("something quick") == nil)
        #expect(PantryCommand.parse("I have eggs") == nil)
    }

    @Test func somethingNotInTheCatalogCanStillBeAdded() {
        let added = lines("add 2 jars of kimchi")
        #expect(added.count == 1)
        #expect(added.first?.item.isCustom == true)
        #expect(added.first?.quantity == 2)
    }

    @Test func nothingToDoIsNil() {
        #expect(PantryCommand.parse("add") == nil)
        #expect(PantryCommand.parse("I only have some eggs left") == nil)
        #expect(PantryCommand.parse("I'm out of ideas") == nil)
    }
}
