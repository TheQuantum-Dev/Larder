//
//  UnitConversion.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation

/// Height and weight are stored in centimetres and kilograms. These are for
/// showing and typing them in feet, inches and pounds.
nonisolated enum UnitConversion {
    static let cmPerInch = 2.54
    static let poundsPerKg = 2.2046226

    static func cm(feet: Int, inches: Int) -> Double {
        Double(feet * 12 + inches) * cmPerInch
    }

    /// Rounded to the nearest inch, so 175 cm reads as 5 ft 9 in.
    static func feetAndInches(fromCm cm: Double) -> (feet: Int, inches: Int) {
        let total = Int((cm / cmPerInch).rounded())
        return (total / 12, total % 12)
    }

    static func kg(pounds: Double) -> Double { pounds / poundsPerKg }
    static func pounds(kg: Double) -> Double { kg * poundsPerKg }
}
