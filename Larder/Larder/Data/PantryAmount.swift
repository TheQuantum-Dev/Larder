//
//  PantryAmount.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import Foundation

/// The handful of units a student kitchen actually uses. Deliberately short:
/// this is "roughly how much is left", not a nutrition scale.
nonisolated enum PantryUnit: String, CaseIterable, Identifiable, Sendable {
    case items, grams = "g", kilograms = "kg", millilitres = "ml", litres = "L",
         packs, cans, bags, bottles

    var id: String { rawValue }

    /// How much one tap of + or − changes the amount.
    var step: Double {
        switch self {
        case .grams, .millilitres: 50
        case .kilograms, .litres: 0.5
        default: 1
        }
    }

    /// Where the amount starts when someone first sets one.
    var starting: Double {
        switch self {
        case .grams, .millilitres: 250
        default: 1
        }
    }

    /// The label on the picker.
    var title: String {
        switch self {
        case .items: "Count"
        case .grams: "Grams"
        case .kilograms: "Kilograms"
        case .millilitres: "Millilitres"
        case .litres: "Litres"
        case .packs: "Packs"
        case .cans: "Cans"
        case .bags: "Bags"
        case .bottles: "Bottles"
        }
    }

    fileprivate func label(for quantity: Double) -> String {
        let one = quantity == 1
        switch self {
        case .items: return ""
        case .grams, .kilograms, .millilitres, .litres: return rawValue
        case .packs: return one ? "pack" : "packs"
        case .cans: return one ? "can" : "cans"
        case .bags: return one ? "bag" : "bags"
        case .bottles: return one ? "bottle" : "bottles"
        }
    }
}

nonisolated enum PantryAmount {
    /// "6", "500 g", "1.5 L", "2 cans". Nil when no amount has been set.
    static func text(quantity: Double?, unit: String?) -> String? {
        guard let quantity else { return nil }
        let number = quantity.rounded() == quantity
            ? String(Int(quantity))
            : quantity.formatted(.number.precision(.fractionLength(0...1)))
        let label = (PantryUnit(rawValue: unit ?? "") ?? .items).label(for: quantity)
        return label.isEmpty ? number : "\(number) \(label)"
    }

    /// One step up or down, never below zero. Zero is allowed on purpose:
    /// it's how "all gone" is said before the item is taken off the list.
    static func stepped(_ quantity: Double, by direction: Int, unit: PantryUnit) -> Double {
        max(0, quantity + Double(direction) * unit.step)
    }
}
