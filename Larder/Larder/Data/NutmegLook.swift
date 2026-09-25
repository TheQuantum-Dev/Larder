//
//  NutmegLook.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation

/// The looks Nutmeg can wear. Amber is the everyday one, Coral is earned by
/// cooking, and Snow and Harvest come with Larder Plus. Each one has a
/// matching app icon.
nonisolated enum NutmegLook: String, CaseIterable, Identifiable, Sendable {
    case amber, coral, snow, harvest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .amber: "Amber"
        case .coral: "Coral"
        case .snow: "Snow"
        case .harvest: "Harvest"
        }
    }

    var blurb: String {
        switch self {
        case .amber: "Nutmeg's everyday look"
        case .coral: "Earned by cooking"
        case .snow: "Beanie, scarf and snowfall"
        case .harvest: "Pumpkin colors and falling leaves"
        }
    }

    var isPlus: Bool { self == .snow || self == .harvest }

    /// The name of the alternate app icon; nil is the regular one.
    var iconName: String? {
        switch self {
        case .amber: nil
        case .coral: "AppIcon-Coral"
        case .snow: "AppIcon-Snow"
        case .harvest: "AppIcon-Harvest"
        }
    }

    /// What it takes to earn a look that isn't given or bought.
    var unlockHint: String? {
        self == .coral ? "Cook \(Self.coralMeals) meals or keep a \(Self.coralStreak)-day streak" : nil
    }

    static let coralStreak = 3
    static let coralMeals = 5

    /// The earned looks that real cooking has unlocked so far.
    static func earned(bestStreak: Int, mealCount: Int) -> Set<NutmegLook> {
        bestStreak >= coralStreak || mealCount >= coralMeals ? [.coral] : []
    }

    func isAvailable(earned: Set<NutmegLook>, hasPlus: Bool) -> Bool {
        switch self {
        case .amber: true
        case .coral: earned.contains(self)
        case .snow, .harvest: hasPlus
        }
    }

    /// A Plus look that Plus no longer covers quietly goes back to amber.
    func effective(hasPlus: Bool) -> NutmegLook {
        isPlus && !hasPlus ? .amber : self
    }
}
