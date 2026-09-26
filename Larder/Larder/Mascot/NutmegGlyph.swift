//
//  NutmegGlyph.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import SwiftUI

/// A tiny Nutmeg for the streak row. It's drawn from the same shapes as the
/// full-size character, in a 100 x 100 space, wearing whichever look is chosen.
/// It has three faces: awake and smiling, asleep, and a bare outline for days
/// that haven't come yet.
///
/// It lives apart from `NutmegView` on purpose. The app-icon tool compiles that
/// file on its own, so it has to stay self-contained.
struct NutmegGlyph: View {
    enum Face { case awake, asleep, outline }

    let face: Face

    @Environment(\.nutmegSkin) private var skin

    private static let pupil = Color(red: 0x3B / 255, green: 0x2A / 255, blue: 0x1A / 255)
    private static let mouth = Color(red: 0x5A / 255, green: 0x3A / 255, blue: 0x1E / 255)

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            var context = context
            context.translateBy(x: (size.width - 100 * scale) / 2, y: (size.height - 100 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            switch face {
            case .awake: drawAwake(&context)
            case .asleep: drawAsleep(&context)
            case .outline: drawOutline(&context)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: - Faces

    private func drawAwake(_ c: inout GraphicsContext) {
        c.fill(oval(41, 89, 7, 4), with: .color(skin.foot))
        c.fill(oval(59, 89, 7, 4), with: .color(skin.foot))
        c.fill(oval(50, 58, 34, 30), with: .color(skin.body))
        c.fill(oval(50, 69, 19, 13), with: .color(skin.belly))
        c.fill(leaf, with: .color(skin.leaf))

        for x in [39.0, 61.0] { c.fill(oval(x, 52, 8, 9), with: .color(.white)) }
        c.fill(oval(41.5, 54, 3.8, 3.8), with: .color(Self.pupil))
        c.fill(oval(63.5, 53, 3.8, 3.8), with: .color(Self.pupil))
        c.fill(oval(43, 52, 1.2, 1.2), with: .color(.white))
        c.fill(oval(65, 51, 1.2, 1.2), with: .color(.white))

        c.fill(oval(26, 64, 3.6, 3.6), with: .color(skin.cheek.opacity(skin.cheekOpacity)))
        c.fill(oval(74, 64, 3.6, 3.6), with: .color(skin.cheek.opacity(skin.cheekOpacity)))

        var smile = Path()
        smile.move(to: CGPoint(x: 43, y: 65))
        smile.addQuadCurve(to: CGPoint(x: 57, y: 65), control: CGPoint(x: 50, y: 74))
        smile.addQuadCurve(to: CGPoint(x: 43, y: 65), control: CGPoint(x: 50, y: 68.5))
        c.fill(smile, with: .color(Self.mouth))
    }

    private func drawAsleep(_ c: inout GraphicsContext) {
        let line = Theme.Palette.textPrimary
        c.fill(oval(50, 58, 34, 30), with: .color(Theme.Palette.background))
        c.stroke(oval(50, 58, 34, 30), with: .color(line.opacity(0.3)), lineWidth: 2.5)
        c.fill(leaf, with: .color(skin.leaf.opacity(0.4)))

        // Shut eyes and a small, calm mouth.
        for x in [39.0, 61.0] {
            var lid = Path()
            lid.move(to: CGPoint(x: x - 8, y: 52))
            lid.addQuadCurve(to: CGPoint(x: x + 8, y: 52), control: CGPoint(x: x, y: 59))
            c.stroke(lid, with: .color(line.opacity(0.55)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
        var mouth = Path()
        mouth.move(to: CGPoint(x: 45, y: 68))
        mouth.addQuadCurve(to: CGPoint(x: 55, y: 68), control: CGPoint(x: 50, y: 71))
        c.stroke(mouth, with: .color(line.opacity(0.45)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    }

    private func drawOutline(_ c: inout GraphicsContext) {
        c.stroke(oval(50, 58, 34, 30), with: .color(Theme.Palette.textPrimary.opacity(0.25)),
                 style: StrokeStyle(lineWidth: 2.5, dash: [5, 5]))
    }

    // MARK: - Shapes

    private func oval(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    /// The leaf tuft on top of his head.
    private var leaf: Path {
        var path = Path()
        path.move(to: CGPoint(x: 50, y: 30))
        path.addCurve(to: CGPoint(x: 54, y: 9), control1: CGPoint(x: 44, y: 22), control2: CGPoint(x: 47, y: 14))
        path.addCurve(to: CGPoint(x: 50, y: 30), control1: CGPoint(x: 56, y: 16), control2: CGPoint(x: 57, y: 24))
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack {
        NutmegGlyph(face: .awake)
        NutmegGlyph(face: .asleep)
        NutmegGlyph(face: .outline)
    }
    .frame(height: 80)
    .padding()
    .background(Theme.Palette.surface)
}
