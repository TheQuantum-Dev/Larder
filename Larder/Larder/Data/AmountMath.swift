//
//  AmountMath.swift
//  Larder
//
//  Created by Joshua Samuel on 9/27/26.
//

import Foundation

/// An amount of something: 6 eggs, 500 g, 2 cans.
nonisolated struct Amount: Equatable, Sendable {
    var quantity: Double
    var unit: PantryUnit

    init(_ quantity: Double, _ unit: PantryUnit = .items) {
        self.quantity = quantity
        self.unit = unit
    }

    /// From what's saved on a pantry or shopping item; nil when no amount is set.
    init?(quantity: Double?, unit: String?) {
        guard let quantity else { return nil }
        self.init(quantity, unit.flatMap(PantryUnit.init(rawValue:)) ?? .items)
    }

    var text: String { PantryAmount.text(quantity: quantity, unit: unit.rawValue) ?? "" }
}

/// Adding amounts together, for when more of something is bought.
nonisolated enum AmountMath {
    /// What you have after adding `more` to `had`. Grams and kilograms (and
    /// millilitres and litres) add up; other different units can't, so the
    /// newer amount stands. With only one amount known, that's the one.
    static func sum(_ had: Amount?, _ more: Amount?) -> Amount? {
        guard let had else { return more }
        guard let more else { return had }
        if had.unit == more.unit { return normalised(Amount(had.quantity + more.quantity, had.unit)) }
        if let a = base(had), let b = base(more), a.unit == b.unit {
            return normalised(Amount(a.quantity + b.quantity, a.unit))
        }
        return more
    }

    /// Kilograms as grams, litres as millilitres; nil for units that don't convert.
    private static func base(_ amount: Amount) -> Amount? {
        switch amount.unit {
        case .grams, .millilitres: amount
        case .kilograms: Amount(amount.quantity * 1000, .grams)
        case .litres: Amount(amount.quantity * 1000, .millilitres)
        default: nil
        }
    }

    /// 1500 g reads better as 1.5 kg, and 250 ml stays as it is.
    static func normalised(_ amount: Amount) -> Amount {
        switch amount.unit {
        case .grams where amount.quantity >= 1000: Amount(amount.quantity / 1000, .kilograms)
        case .millilitres where amount.quantity >= 1000: Amount(amount.quantity / 1000, .litres)
        default: amount
        }
    }

    /// A weight rounded up to what's easy to buy: the next 50 g, or the next
    /// half kilo from a kilo up.
    static func toBuy(grams: Double, liquid: Bool = false) -> Amount {
        if grams >= 1000 {
            return Amount((grams / 500).rounded(.up) / 2, liquid ? .litres : .kilograms)
        }
        return Amount(max(50, (grams / 50).rounded(.up) * 50), liquid ? .millilitres : .grams)
    }
}
