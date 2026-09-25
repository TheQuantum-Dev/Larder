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
    }

    /// The look he's wearing: the one chosen, unless it needs Plus and Plus isn't active.
    private var look: NutmegLook {
        (NutmegLook(rawValue: lookName) ?? .amber).effective(hasPlus: purchaseStore.isPlusActive)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(purchaseStore)
                .environment(\.nutmegSkin, look.skin)
                .modelContainer(for: [PantryItem.self, CookedMeal.self, ShoppingItem.self])
                .fontDesign(.rounded)
                .task { await purchaseStore.start() }
                .task { SoundPlayer.prepare() }
        }
    }
}
