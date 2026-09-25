//
//  NutmegLook+Skin.swift
//  Larder
//
//  Created by Joshua Samuel on 9/25/26.
//

import Foundation

extension NutmegLook {
    /// The colors and outfit for this look. Kept apart from `NutmegLook` so
    /// the look itself needs no drawing code.
    var skin: NutmegSkin {
        switch self {
        case .amber: .amber
        case .coral: .coral
        case .snow: .snow
        case .harvest: .harvest
        }
    }
}
