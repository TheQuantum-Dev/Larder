//
//  PlanMathTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation
import Testing
@testable import Larder

struct PlanMathTests {

    @Test func semesterSavesAboutThirtyNinePercent() {
        // $10.99 for six months versus six months of $2.99.
        #expect(PlanMath.savingsPercent(monthlyPrice: 2.99, planPrice: 10.99, months: 6) == 39)
    }

    @Test func noSavingsWhenPlanIsNotCheaper() {
        #expect(PlanMath.savingsPercent(monthlyPrice: 2.99, planPrice: 17.94, months: 6) == nil)
        #expect(PlanMath.savingsPercent(monthlyPrice: 2.99, planPrice: 20.00, months: 6) == nil)
    }

    @Test func rejectsNonsenseInput() {
        #expect(PlanMath.savingsPercent(monthlyPrice: 0, planPrice: 10.99, months: 6) == nil)
        #expect(PlanMath.savingsPercent(monthlyPrice: 2.99, planPrice: 10.99, months: 0) == nil)
    }
}
