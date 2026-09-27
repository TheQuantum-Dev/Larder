//
//  LarderApp.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import RevenueCat
import SwiftData
import SwiftUI

@main
struct LarderApp: App {
    @State private var purchaseStore = PurchaseStore()
    @AppStorage(AppSettings.nutmegLookKey) private var lookName = NutmegLook.amber.rawValue

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        // Colors from the first frame on, before any view has asked.
        let saved = UserDefaults.standard.string(forKey: AppSettings.nutmegLookKey)
        ThemeStore.shared.look = saved.flatMap(NutmegLook.init(rawValue:)) ?? .amber
    }

    /// The look he's wearing: the one chosen, unless it needs Plus and Plus
    /// isn't active. Until that's known, the chosen one, so the app doesn't
    /// flicker from snow to amber and back while it checks.
    private var look: NutmegLook {
        let chosen = NutmegLook(rawValue: lookName) ?? .amber
        guard purchaseStore.hasLoadedEntitlements else { return chosen }
        return chosen.effective(hasPlus: purchaseStore.isPlusActive)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(purchaseStore)
                .environment(\.nutmegSkin, look.skin)
                // The whole app takes on the look's colors.
                .onChange(of: look, initial: true) { _, look in ThemeStore.shared.look = look }
                .modelContainer(for: [PantryItem.self, CookedMeal.self, ShoppingItem.self, RecipeNote.self])
                .fontDesign(.rounded)
                .task { await purchaseStore.start() }
                .task { SoundPlayer.prepare() }
        }
    }
}
