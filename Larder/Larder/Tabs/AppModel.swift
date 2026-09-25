//
//  AppModel.swift
//  Larder
//
//  Created by Joshua Samuel on 9/24/26.
//

import Foundation
import Observation

nonisolated enum AppTab: String, Hashable, CaseIterable, Sendable {
    case home, pantry, recipes, insights, nutmeg
}

/// The little bit of state every tab shares: which tab is showing, whether
/// the scan sheet is up, and what the person told us about how they eat.
/// Kept small on purpose; each tab reads its own data straight from SwiftData.
@Observable
final class AppModel {
    var tab: AppTab
    var showScan = false
    /// A look that was just earned and hasn't been shown off yet.
    var unlockedLook: NutmegLook?
    /// Goes up when Nutmeg has something to cheer about on Home.
    var homeCheer = 0
    /// Settings opens from Home's gear and from prompts on other tabs, so one
    /// sheet at the root serves them all.
    var showSettings = AppModel.launchOpensSettings
    private(set) var profile: Profile

    init(tab: AppTab = AppModel.launchTab, profile: Profile = AppModel.launchProfile) {
        self.tab = tab
        self.profile = profile
    }

    /// Called after Settings closes, so diet changes reach every tab.
    func reloadProfile() {
        profile = ProfileStore.load()
    }

    /// `-openSettings YES` opens Settings on launch (debug builds only).
    private static var launchOpensSettings: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "openSettings")
        #else
        return false
        #endif
    }

    /// `-goal buildMuscle` sets the fitness goal for this launch (debug builds only).
    private static var launchProfile: Profile {
        var profile = ProfileStore.load()
        #if DEBUG
        if let name = UserDefaults.standard.string(forKey: "goal"), FitnessGoal(rawValue: name) != nil {
            profile.goal = name
        }
        #endif
        return profile
    }

    /// `-tab pantry` opens straight onto a tab (debug builds only).
    private static var launchTab: AppTab {
        #if DEBUG
        if let name = UserDefaults.standard.string(forKey: "tab"), let tab = AppTab(rawValue: name) {
            return tab
        }
        #endif
        return .home
    }
}
