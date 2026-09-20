//
//  PillButtonStyle.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// A fully rounded button with a darker edge underneath, so it looks like a
/// physical key that presses down when tapped.
struct PillButtonStyle: ButtonStyle {
    var fill: Color = Theme.Palette.amber

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let depth = Theme.buttonDepth
        let pressed = configuration.isPressed

        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.Palette.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.s)
            .background(Capsule().fill(fill))
            // The face drops onto its edge while pressed.
            .offset(y: pressed ? depth : 0)
            // The edge is added after the offset, so it stays put.
            .background(Capsule().fill(fill.mix(with: .black, by: 0.25)).offset(y: depth))
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
    }
}
