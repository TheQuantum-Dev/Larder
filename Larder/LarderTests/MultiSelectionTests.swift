//
//  MultiSelectionTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/20/26.
//

import Testing
@testable import Larder

@MainActor
struct MultiSelectionTests {

    @Test func togglingAddsThenRemoves() {
        var selection = MultiSelection<Diet>()
        selection.toggle(.vegan)
        #expect(selection.contains(.vegan))
        selection.toggle(.vegan)
        #expect(selection.isEmpty)
    }

    @Test func manyOptionsCanBePickedTogether() {
        var selection = MultiSelection<Diet>(exclusive: .noRestrictions)
        selection.toggle(.vegan)
        selection.toggle(.nutFree)
        #expect(selection.items == [.vegan, .nutFree])
    }

    @Test func exclusiveOptionClearsTheOthers() {
        var selection = MultiSelection<Diet>(exclusive: .noRestrictions)
        selection.toggle(.vegan)
        selection.toggle(.halal)
        selection.toggle(.noRestrictions)
        #expect(selection.items == [.noRestrictions])
    }

    @Test func pickingSomethingElseClearsTheExclusiveOption() {
        var selection = MultiSelection<Diet>(exclusive: .noRestrictions)
        selection.toggle(.noRestrictions)
        selection.toggle(.vegetarian)
        #expect(selection.items == [.vegetarian])
    }

    @Test func orderedFollowsTheOrderOnScreenNotTheOrderPicked() {
        var selection = MultiSelection<Priority>()
        selection.toggle(.fast)
        selection.toggle(.saveMoney)
        #expect(selection.ordered == [.saveMoney, .fast])
    }

    @Test func progressStartsPartlyFilledAndEndsFull() {
        #expect(OnboardingStep.diet.progress > 0.1)
        #expect(OnboardingStep.allCases.last?.progress == 1)
    }
}
