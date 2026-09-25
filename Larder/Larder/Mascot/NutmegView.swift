//
//  NutmegView.swift
//  Larder
//
//  Created by Joshua Samuel on 9/20/26.
//

import SwiftUI

/// Nutmeg, drawn from the reference poses in the repo root (nutmeg-reference.svg
/// and nutmeg-pose-*.svg). Every shape, coordinate and color below comes
/// straight from those files, in their shared 680 x 530 coordinate space, and
/// the whole drawing is scaled to fit whatever size the caller gives it.
struct NutmegView: View {
    /// How Nutmeg is behaving. `idle` is the resting loop; `peeking` is the
    /// curious look-around he does while something is being worked out; and
    /// `celebrating` is a happy hop with a fast wave.
    enum Mood { case idle, peeking, celebrating }

    /// Which arms are showing. `noHands` is the everyday look — used almost
    /// everywhere, including the launch screen. The waves and the two-handed
    /// cheer are saved for moments that actually call for them: a greeting,
    /// a celebration.
    enum Pose { case noHands, rightWave, leftWave, bothWave, resting }

    var mood: Mood = .idle
    var pose: Pose = .noHands
    /// Overrides the person's chosen look; most callers leave it out and get
    /// whatever look is set in Settings.
    var skin: NutmegSkin?
    /// Each time one of these goes up by one, Nutmeg does a one-off reaction:
    /// an approving nod, or a little cheer.
    var nod = 0
    var cheer = 0
    /// Falling snow or leaves on the seasonal looks. Off for the app icon.
    var showsWeather = true

    private static let artSize = CGSize(width: 680, height: 530)

    @Environment(\.nutmegSkin) private var environmentSkin
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swaying = false
    @State private var looking = false
    @State private var hopping = false

    private var look: NutmegSkin { skin ?? environmentSkin }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / Self.artSize.width,
                            proxy.size.height / Self.artSize.height)
            art
                .keyframeAnimator(initialValue: Bump(), trigger: reduceMotion ? 0 : nod) { content, bump in
                    content.offset(y: bump.lift)
                } keyframes: { _ in
                    KeyframeTrack(\.lift) {
                        CubicKeyframe(22, duration: 0.15)
                        CubicKeyframe(0, duration: 0.15)
                        CubicKeyframe(16, duration: 0.13)
                        CubicKeyframe(0, duration: 0.17)
                    }
                }
                .keyframeAnimator(initialValue: Bump(), trigger: reduceMotion ? 0 : cheer) { content, bump in
                    content
                        .offset(y: bump.lift)
                        .rotationEffect(.degrees(bump.tilt), anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack(\.lift) {
                        CubicKeyframe(-70, duration: 0.22)
                        CubicKeyframe(0, duration: 0.22)
                        CubicKeyframe(-40, duration: 0.18)
                        CubicKeyframe(0, duration: 0.2)
                    }
                    KeyframeTrack(\.tilt) {
                        CubicKeyframe(-8, duration: 0.2)
                        CubicKeyframe(8, duration: 0.25)
                        CubicKeyframe(-5, duration: 0.2)
                        CubicKeyframe(0, duration: 0.2)
                    }
                }
                .overlay {
                    if showsWeather, look.weather != .none, !reduceMotion, proxy.size.height >= 100 {
                        Weather(kind: look.weather)
                            .allowsHitTesting(false)
                    }
                }
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
                if mood == .celebrating { hopping = true }
            }
        }
    }

    /// Pupils sweep side to side while peeking.
    private var pupilShift: CGFloat { mood == .peeking ? (looking ? 14 : -14) : 0 }
    private var pupilLift: CGFloat { mood == .peeking ? -4 : 0 }
    private var tilt: Double { mood == .peeking ? (looking ? 5 : -5) : 0 }
    private var hop: CGFloat { mood == .celebrating ? (hopping ? -40 : 0) : 0 }
    /// How far a raised arm swings: a gentle sway at rest, a big shake when celebrating.
    private var armSwing: Double { mood == .celebrating ? 18 : 4 }
    private var swayDuration: Double { mood == .celebrating ? 0.3 : 1.3 }

    private var art: some View {
        ZStack {
            // Body and belly, breathing together.
            ZStack {
                ellipse(340, 335, 160, 148, look.body)
                ellipse(340, 385, 92, 68, look.belly)
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
            .fill(look.leaf)

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
            circle(248, 345, 16, look.cheek, opacity: look.cheekOpacity)
            circle(432, 345, 16, look.cheek, opacity: look.cheekOpacity)

            // Open smile.
            Path { p in
                p.move(to: CGPoint(x: 296, y: 370))
                p.addQuadCurve(to: CGPoint(x: 384, y: 370), control: CGPoint(x: 340, y: 412))
                p.addQuadCurve(to: CGPoint(x: 296, y: 370), control: CGPoint(x: 340, y: 386))
                p.closeSubpath()
            }
            .fill(Palette.mouth)

            if look.accessory == .winter {
                winterGear
            }

            arms

            // Feet.
            ellipse(300, 472, 30, 18, look.foot)
            ellipse(382, 472, 30, 18, look.foot)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: swayDuration).repeatForever(autoreverses: true),
                   value: swaying)
        .offset(y: hop)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.4).repeatForever(autoreverses: true),
                   value: hopping)
        .rotationEffect(.degrees(tilt), anchor: .bottom)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                   value: looking)
    }

    // MARK: - Arms

    @ViewBuilder
    private var arms: some View {
        switch pose {
        case .noHands:
            EmptyView()
        case .resting:
            restingPaw(cx: 238)
            restingPaw(cx: 442)
        case .rightWave:
            restingPaw(cx: 238)
            rightWavingArm
        case .leftWave:
            restingPaw(cx: 442)
            leftWavingArm
        case .bothWave:
            leftWavingArm
            rightWavingArm
        }
    }

    /// A stubby paw at rest, with three small toe-pad marks.
    private func restingPaw(cx: CGFloat) -> some View {
        ZStack {
            ellipse(cx, 430, 34, 26, look.body)
            ellipse(cx - 13, 417, 6, 7, look.foot)
            ellipse(cx, 414, 6, 7, look.foot)
            ellipse(cx + 13, 417, 6, 7, look.foot)
        }
    }

    /// The right arm, raised and swinging from the shoulder.
    private var rightWavingArm: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 478, y: 352))
                p.addCurve(to: CGPoint(x: 528, y: 245),
                           control1: CGPoint(x: 500, y: 330), control2: CGPoint(x: 510, y: 280))
            }
            .stroke(look.body, style: StrokeStyle(lineWidth: 30, lineCap: .round))
            circle(530, 238, 34, look.body)
            ellipse(517, 225, 6, 7, look.foot)
            ellipse(530, 222, 6, 7, look.foot)
            ellipse(543, 225, 6, 7, look.foot)
        }
        .rotationEffect(.degrees(swaying ? -armSwing : armSwing),
                        anchor: UnitPoint(x: 478 / Self.artSize.width, y: 352 / Self.artSize.height))
    }

    /// The left arm, raised and swinging — the mirror image of the right,
    /// swung the opposite way so two-armed poses shake in sync.
    private var leftWavingArm: some View {
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 202, y: 352))
                p.addCurve(to: CGPoint(x: 152, y: 245),
                           control1: CGPoint(x: 180, y: 330), control2: CGPoint(x: 170, y: 280))
            }
            .stroke(look.body, style: StrokeStyle(lineWidth: 30, lineCap: .round))
            circle(150, 238, 34, look.body)
            ellipse(163, 225, 6, 7, look.foot)
            ellipse(150, 222, 6, 7, look.foot)
            ellipse(137, 225, 6, 7, look.foot)
        }
        .rotationEffect(.degrees(swaying ? armSwing : -armSwing),
                        anchor: UnitPoint(x: 202 / Self.artSize.width, y: 352 / Self.artSize.height))
    }

    private func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat,
                         _ color: Color) -> some View {
        Ellipse().fill(color).frame(width: rx * 2, height: ry * 2).position(x: cx, y: cy)
    }

    private func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat,
                        _ color: Color, opacity: Double = 1) -> some View {
        Circle().fill(color).opacity(opacity).frame(width: r * 2, height: r * 2).position(x: cx, y: cy)
    }

    /// Colors that don't change with the look.
    private enum Palette {
        static let pupil = Color(red: 0x3B / 255, green: 0x2A / 255, blue: 0x1A / 255)
        static let mouth = Color(red: 0x5A / 255, green: 0x3A / 255, blue: 0x1E / 255)
    }

    // MARK: - Winter gear

    /// A beanie with the leaf poking through, and a scarf around his middle.
    @ViewBuilder
    private var winterGear: some View {
        let hat = Color(red: 0xD6 / 255, green: 0x4A / 255, blue: 0x4A / 255)
        let fluff = Color(red: 0xF7 / 255, green: 0xF3 / 255, blue: 0xEA / 255)
        let scarf = Color(red: 0x8C / 255, green: 0xAE / 255, blue: 0x66 / 255)
        ZStack {
            // Scarf, with a tail hanging on the right.
            RoundedRectangle(cornerRadius: 17).fill(scarf)
                .frame(width: 300, height: 34).position(x: 340, y: 446)
            RoundedRectangle(cornerRadius: 12).fill(scarf)
                .frame(width: 38, height: 76).position(x: 452, y: 478)
            // Beanie: dome, then a cuff, then a pom-pom.
            Path { p in
                p.move(to: CGPoint(x: 222, y: 238))
                p.addCurve(to: CGPoint(x: 458, y: 238),
                           control1: CGPoint(x: 232, y: 108), control2: CGPoint(x: 448, y: 108))
                p.closeSubpath()
            }
            .fill(hat)
            RoundedRectangle(cornerRadius: 19).fill(fluff)
                .frame(width: 264, height: 38).position(x: 340, y: 232)
            Circle().fill(fluff)
                .frame(width: 44, height: 44).position(x: 418, y: 160)
        }
    }

    /// One frame of a one-off reaction.
    private struct Bump {
        var lift: CGFloat = 0
        var tilt: Double = 0
    }

    // MARK: - Falling snow and leaves

    /// Slow snow or drifting leaves in front of Nutmeg, worked out from the
    /// clock so there's nothing to keep track of.
    private struct Weather: View {
        let kind: NutmegSkin.Weather

        var body: some View {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    for index in 0..<16 {
                        let i = Double(index)
                        let speed = 34 + Double(index % 5) * 12
                        let x = (i * 0.618).truncatingRemainder(dividingBy: 1) * size.width
                        let phase = (i * 0.377).truncatingRemainder(dividingBy: 1) * size.height
                        let y = (phase + time * speed).truncatingRemainder(dividingBy: size.height)
                        let drift = sin(time * 0.9 + i) * 16
                        let center = CGPoint(x: x + drift, y: y)
                        switch kind {
                        case .snow:
                            let r = 4.0 + Double(index % 3) * 2
                            context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                                         with: .color(.white.opacity(0.92)))
                        case .leaves:
                            var leaf = context
                            leaf.translateBy(x: center.x, y: center.y)
                            leaf.rotate(by: .radians(time * 1.4 + i))
                            let colors: [Color] = [Color(red: 0.86, green: 0.36, blue: 0.16),
                                                   Color(red: 0.93, green: 0.65, blue: 0.16),
                                                   Color(red: 0.70, green: 0.28, blue: 0.14)]
                            leaf.fill(Path(ellipseIn: CGRect(x: -9, y: -5, width: 18, height: 10)),
                                      with: .color(colors[index % 3]))
                        case .none:
                            break
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Looks

/// A look for Nutmeg: the same character in different colors, sometimes with
/// something to wear or weather around him. It lives in this file so the tool
/// that draws the app icons, which draws Nutmeg on his own, needs nothing else.
struct NutmegSkin: Hashable {
    var body: Color
    var belly: Color
    var leaf: Color
    var foot: Color
    var cheek: Color
    var cheekOpacity = 0.35
    var accessory = Accessory.none
    var weather = Weather.none

    enum Accessory { case none, winter }
    enum Weather { case none, snow, leaves }

    private static func hex(_ value: UInt32) -> Color {
        Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255)
    }

    /// The approved reference colors. Nutmeg's everyday look.
    static let amber = NutmegSkin(body: hex(0xF0A83A), belly: hex(0xF6C067), leaf: hex(0x8CAE66),
                                  foot: hex(0xD98F2A), cheek: hex(0xE8654A))

    /// Earned by cooking. The cheeks are paler than his body so they show.
    static let coral = NutmegSkin(body: hex(0xE86A45), belly: hex(0xF4A283), leaf: hex(0x8CAE66),
                                  foot: hex(0xC4522F), cheek: hex(0xFFD2C2), cheekOpacity: 0.85)

    /// Winter: a beanie, a scarf and snow.
    static let snow = NutmegSkin(body: hex(0xF0A83A), belly: hex(0xF6C067), leaf: hex(0x8CAE66),
                                 foot: hex(0xD98F2A), cheek: hex(0xE8654A), accessory: .winter, weather: .snow)

    /// Autumn: pumpkin colors and drifting leaves.
    static let harvest = NutmegSkin(body: hex(0xE2822B), belly: hex(0xF3B25C), leaf: hex(0x9C4A22),
                                    foot: hex(0xB8651C), cheek: hex(0xD9452B), weather: .leaves)

    /// Grayscale, for the tinted app icon.
    static let mono = NutmegSkin(body: hex(0x4A4A4A), belly: hex(0x6E6E6E), leaf: hex(0x7A7A7A),
                                 foot: hex(0x363636), cheek: hex(0x9A9A9A))
}

extension EnvironmentValues {
    /// The look Nutmeg wears everywhere unless a view says otherwise.
    @Entry var nutmegSkin = NutmegSkin.amber
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ForEach([NutmegView.Pose.noHands, .rightWave, .leftWave, .bothWave, .resting], id: \.self) { pose in
                NutmegView(pose: pose)
                    .frame(height: 160)
            }
            ForEach([NutmegSkin.coral, .snow, .harvest], id: \.self) { skin in
                NutmegView(skin: skin)
                    .frame(height: 160)
            }
        }
        .padding()
    }
    .background(Theme.Palette.background)
}

extension NutmegView.Pose: Hashable {}
