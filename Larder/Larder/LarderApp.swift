//
//  LarderApp.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI
import RevenueCat

@main
struct LarderApp: App {
    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
