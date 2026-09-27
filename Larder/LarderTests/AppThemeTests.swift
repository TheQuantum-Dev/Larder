//
//  AppThemeTests.swift
//  LarderTests
//
//  Created by Joshua Samuel on 9/27/26.
//

import Foundation
import Testing
@testable import Larder

/// Every look's colors have to stay readable, in light and dark mode.
struct AppThemeTests {
    private let themes: [(String, AppTheme)] = [("amber", .amber), ("coral", .coral), ("snow", .snow),
                                                 ("harvest", .harvest)]

    /// WCAG contrast between two colors, from 1 to 21.
    private func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        func luminance(_ hex: UInt32) -> Double {
            func channel(_ shift: UInt32) -> Double {
                let c = Double((hex >> shift) & 0xFF) / 255
                return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
        }
        let (l1, l2) = (luminance(a), luminance(b))
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    @Test func textIsReadableOnEveryBackground() {
        for (name, theme) in themes {
            for (text, background, surface) in [(theme.textHex.light, theme.backgroundHex.light, theme.surfaceHex.light),
                                                (theme.textHex.dark, theme.backgroundHex.dark, theme.surfaceHex.dark)] {
                #expect(contrast(text, background) >= 7, "\(name) text on background")
                #expect(contrast(text, surface) >= 7, "\(name) text on surface")
            }
        }
    }

    @Test func buttonTextIsReadableOnTheMainColors() {
        for (name, theme) in themes {
            #expect(contrast(theme.onAccentHex, theme.accentHex) >= 4.5, "\(name) button text")
            let soft = AppTheme.mixWithWhite(theme.accentHex, by: AppTheme.softMix)
            #expect(contrast(theme.onAccentHex, soft) >= 4.5, "\(name) soft button text")
        }
    }

    @Test func everyLookHasItsOwnColors() {
        #expect(Set(themes.map(\.1.accentHex)).count == 4)
        #expect(NutmegLook.snow.theme.accentHex == AppTheme.snow.accentHex)
    }
}
