//
//  PlanMath.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation

enum PlanMath {
    /// Percent saved by a multi-month plan compared with paying monthly for the
    /// same stretch of time. Nil when the plan isn't actually cheaper.
    nonisolated static func savingsPercent(monthlyPrice: Decimal, planPrice: Decimal, months: Int) -> Int? {
        guard months > 0, monthlyPrice > 0 else { return nil }
        let full = NSDecimalNumber(decimal: monthlyPrice).doubleValue * Double(months)
        let plan = NSDecimalNumber(decimal: planPrice).doubleValue
        guard plan < full else { return nil }
        return Int(((full - plan) / full * 100).rounded())
    }
}
