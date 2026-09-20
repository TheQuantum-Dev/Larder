//
//  RevenueCatConfig.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation

/// RevenueCat configuration.
///
/// These are public SDK keys, which RevenueCat designs to ship inside apps,
/// so they are committed here on purpose.
enum RevenueCatConfig {
    /// The entitlement that unlocks the paid features.
    static let entitlementID = "larder_plus"

    // The Test Store key must never ship in a release build (the SDK crashes
    // if it sees one), so debug and release use different keys.
    #if DEBUG
    static let apiKey = "test_nuWyCBuSSePikXhSGbNpNRVmtsh"
    #else
    static let apiKey = "REPLACE_WITH_APP_STORE_KEY"
    #endif
}
