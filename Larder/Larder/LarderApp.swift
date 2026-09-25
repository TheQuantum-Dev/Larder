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

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(purchaseStore)
                .modelContainer(for: [PantryItem.self, CookedMeal.self, ShoppingItem.self])
                .fontDesign(.rounded)
                .task { await purchaseStore.start() }
                .task { SoundPlayer.prepare() }
        }
    }
}
