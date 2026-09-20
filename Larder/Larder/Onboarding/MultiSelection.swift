//
//  MultiSelection.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import Foundation

/// A set of picked options for a multi-select question. One option can be
/// marked exclusive, like "No restrictions": choosing it clears everything
/// else, and choosing anything else clears it.
struct MultiSelection<Option: Hashable> {
    private(set) var items: Set<Option> = []
    let exclusive: Option?

    init(exclusive: Option? = nil) {
        self.exclusive = exclusive
    }

    var isEmpty: Bool { items.isEmpty }

    func contains(_ option: Option) -> Bool { items.contains(option) }

    mutating func toggle(_ option: Option) {
        if items.contains(option) {
            items.remove(option)
        } else if option == exclusive {
            items = [option]
        } else {
            if let exclusive { items.remove(exclusive) }
            items.insert(option)
        }
    }
}

extension MultiSelection where Option: CaseIterable {
    /// The picked options in the same order they appear on screen.
    var ordered: [Option] {
        Option.allCases.filter { items.contains($0) }
    }
}
