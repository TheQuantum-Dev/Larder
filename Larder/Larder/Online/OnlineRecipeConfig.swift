//
//  OnlineRecipeConfig.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation

/// Whether this build can look recipes up online at all. The lookups use a free
/// spoonacular key, which is a secret: it lives in `Config/spoonacular.key`,
/// a file that is kept out of the repository, and is read from there when the
/// app runs. Without the file everything works as before on the bundled
/// recipes, and the online parts stay out of sight.
nonisolated enum OnlineRecipeConfig {
    static let keyFileName = "spoonacular"
    static let keyFileExtension = "key"

    static let apiKey: String? = key(in: .main)

    /// Reads the key from a bundle, or nil if there's no file or nothing in it.
    static func key(in bundle: Bundle) -> String? {
        guard let url = bundle.url(forResource: keyFileName, withExtension: keyFileExtension),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }

    /// True when there is a key to use, or, in debug builds, when
    /// `-fakeOnline YES` swaps in sample recipes so the feature can be seen
    /// without a key or a network.
    static var isAvailable: Bool {
        #if DEBUG
        if usesFakeAPI { return true }
        #endif
        return apiKey != nil
    }

    #if DEBUG
    static var usesFakeAPI: Bool { UserDefaults.standard.bool(forKey: "fakeOnline") }
    #endif
}
