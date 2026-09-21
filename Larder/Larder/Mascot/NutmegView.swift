//
//  NutmegView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// Nutmeg, drawn from nutmeg-reference.svg. Every shape, coordinate and color
/// below comes straight from that file, in its 680 x 530 coordinate space, and
/// the whole drawing is scaled to fit whatever size the caller gives it.
struct NutmegView: View {
    /// How Nutmeg is behaving. `idle` is the resting loop; `peeking` is the
    /// curious look-around he does while something is being worked out.
    enum Mood { case idle, peeking }

    var mood: Mood = .idle

    private static let artSize = CGSize(width: 680, height: 530)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swaying = false
    @State private var looking = false

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / Self.artSize.width,
                            proxy.size.height / Self.artSize.height)
            art
                .frame(width: Self.artSize.width, height: Self.artSize.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: Self.artSize.width * scale,
                       height: Self.artSize.height * scale,
                       alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(Self.artSize, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Nutmeg, the Larder mascot")
        .onAppear {
            // A resting loop so Nutmeg is never a static frame.
            if !reduceMotion {
                swaying = true
                if mood == .peeking { looking = true }
            }
        }
    }

    /// Pupils sweep side to side while peeking.
    private var pupilShift: CGFloat { mood == .peeking ? (looking ? 14 : -14) : 0 }
    private var pupilLift: CGFloat { mood == .peeking ? -4 : 0 }
    private var tilt: Double { mood == .peeking ? (looking ? 5 : -5) : 0 }

    private var art: some View {
        ZStack {
            // Body and belly, breathing together.
            ZStack {
                ellipse(340, 335, 160, 148, Palette.amber)
                ellipse(340, 385, 92, 68, Palette.belly)
            }
            .scaleEffect(y: swaying ? 1.02 : 1, anchor: .bottom)

            // Leaf tuft.
            Path { p in
                p.move(to: CGPoint(x: 340, y: 185))
                p.addCurve(to: CGPoint(x: 352, y: 85),
                           control1: CGPoint(x: 318, y: 150), control2: CGPoint(x: 330, y: 108))
                p.addCurve(to: CGPoint(x: 340, y: 185),
                           control1: CGPoint(x: 362, y: 112), control2: CGPoint(x: 372, y: 148))
                p.closeSubpath()
            }
            .fill(Palette.leaf)

            // Eyes, pupils and highlights.
            ellipse(285, 300, 40, 44, .white)
            ellipse(395, 300, 40, 44, .white)
            Group {
                circle(298, 308, 18, Palette.pupil)
                circle(408, 304, 18, Palette.pupil)
                circle(304, 302, 5, .white)
                circle(414, 298, 5, .white)
            }
            .offset(x: pupilShift, y: pupilLift)

            // Cheeks.
            circle(248, 345, 16, Palette.cheek, opacity: 0.35)
            circle(432, 345, 16, Palette.cheek, opacity: 0.35)

            // Open smile.
            Path { p in
                p.move(to: CGPoint(x: 296, y: 370))
                p.addQuadCurve(to: CGPoint(x: 384, y: 370), control: CGPoint(x: 340, y: 412))
                p.addQuadCurve(to: CGPoint(x: 296, y: 370), control: CGPoint(x: 340, y: 386))
                p.closeSubpath()
            }
            .fill(Palette.mouth)

            // Stubby left arm.
            ellipse(238, 430, 34, 26, Palette.amber)

            // Raised right arm and hand, swaying from the shoulder.
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 478, y: 352))
                    p.addCurve(to: CGPoint(x: 528, y: 245),
                               control1: CGPoint(x: 500, y: 330), control2: CGPoint(x: 510, y: 280))
                }
                .stroke(Palette.amber, style: StrokeStyle(lineWidth: 30, lineCap: .round))
                circle(530, 238, 34, Palette.amber)
            }
            .rotationEffect(.degrees(swaying ? -4 : 4),
                            anchor: UnitPoint(x: 478 / Self.artSize.width, y: 352 / Self.artSize.height))

            // Feet.
            ellipse(300, 472, 30, 18, Palette.foot)
            ellipse(382, 472, 30, 18, Palette.foot)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                   value: swaying)
        .rotationEffect(.degrees(tilt), anchor: .bottom)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                   value: looking)
    }

    private func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                         _ color: Color) -> some View {
        Ellipse().fill(color).frame(width: rx * 2, height: ry * 2).position(x: cx, y: cy)
    }

    private func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat,
                        _ color: Color, opacity: Double = 1) -> some View {
        Circle().fill(color).opacity(opacity).frame(width: r * 2, height: r * 2).position(x: cx, y: cy)
    }

    /// Colors from the reference artwork. Fixed on purpose: Nutmeg looks the
    /// same in light and dark mode.
    private enum Palette {
        static let amber = Color(red: 0xF0 / 255, green: 0xA8 / 255, blue: 0x3A / 255)
        static let belly = Color(red: 0xF6 / 255, green: 0xC0 / 255, blue: 0x67 / 255)
        static let leaf = Color(red: 0x8C / 255, green: 0xAE / 255, blue: 0x66 / 255)
        static let pupil = Color(red: 0x3B / 255, green: 0x2A / 255, blue: 0x1A / 255)
        static let cheek = Color(red: 0xE8 / 255, green: 0x65 / 255, blue: 0x4A / 255)
        static let mouth = Color(red: 0x5A / 255, green: 0x3A / 255, blue: 0x1E / 255)
        static let foot = Color(red: 0xD9 / 255, green: 0x8F / 255, blue: 0x2A / 255)
    }
}

#Preview {
    NutmegView()
        .frame(height: 300)
        .padding()
        .background(Theme.Palette.background)
}
