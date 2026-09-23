//
//  BarcodeProductTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/22/26.
//

import Testing
@testable import Larder

struct BarcodeProductTests {
    private func product(_ name: String) -> BarcodeProduct {
        BarcodeProduct(barcode: "0000000000000", name: name)
    }

    @Test func aBrandedNameStillFindsTheIngredientInsideIt() {
        #expect(product("Organic Whole Milk, Vitamin D").resolvedItem.id == "milk")
        #expect(product("Kraft Mild Cheddar Cheese Block").resolvedItem.id == "cheese")
    }

    @Test func aNameNothingMatchesBecomesACustomItem() {
        let item = product("Astro Blast Fizzy Drink").resolvedItem
        #expect(item.isCustom)
        #expect(item.name == "Astro Blast Fizzy Drink")
    }

    @Test func twoProductsOfTheSameIngredientResolveToTheSameID() {
        let a = product("Silk Almond Milk, Unsweetened").resolvedItem
        let b = product("Horizon Organic Whole Milk").resolvedItem
        #expect(a.id == b.id)
        #expect(a.id == "milk")
    }
}
