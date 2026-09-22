//
//  PurchaseStore.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation
import Observation
import RevenueCat

/// The app's window onto RevenueCat: which plans are on offer and whether the
/// paid entitlement is active. Views read from this and call into it; nothing
/// else in the app talks to RevenueCat directly.
@Observable
final class PurchaseStore {
    enum LoadState { case loading, loaded, failed }
    enum PurchaseOutcome { case purchased, cancelled, failed(String) }

    private(set) var loadState: LoadState = .loading
    private(set) var semester: Package?
    private(set) var monthly: Package?
    private(set) var isPlusActive = false

    /// Loads the plans, then keeps the entitlement status up to date for as
    /// long as the caller's task is alive.
    func start() async {
        await loadOfferings()
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info)
        }
        for await info in Purchases.shared.customerInfoStream {
            apply(info)
        }
    }

    func loadOfferings() async {
        loadState = .loading
        do {
            let offerings = try await Purchases.shared.offerings()
            semester = offerings.current?.sixMonth
            monthly = offerings.current?.monthly
            loadState = (semester != nil || monthly != nil) ? .loaded : .failed
        } catch {
            loadState = .failed
        }
    }

    func purchase(_ package: Package) async -> PurchaseOutcome {
        do {
            let result = try await Purchases.shared.purchase(package: package)
            apply(result.customerInfo)
            return result.userCancelled ? .cancelled : .purchased
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Returns whether Larder Plus is active afterwards.
    func restore() async -> Bool {
        if let info = try? await Purchases.shared.restorePurchases() {
            apply(info)
        }
        return isPlusActive
    }

    private func apply(_ info: CustomerInfo) {
        isPlusActive = info.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
        #if DEBUG
        // `-forcePlus YES` pretends Plus is on, to look at paid screens without buying.
        if UserDefaults.standard.bool(forKey: "forcePlus") { isPlusActive = true }
        #endif
    }
}
