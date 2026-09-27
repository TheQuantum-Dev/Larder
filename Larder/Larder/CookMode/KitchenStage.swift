//
//  KitchenStage.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import SwiftUI

/// A little kitchen above each Cook Mode step, with Nutmeg in a chef's hat
/// doing whatever the step says: stirring a bubbling pot, frying, chopping,
/// watching the toaster. Everything moves from the clock, so there's nothing
/// to keep track of, and it speeds up while the step's timer is running.
///
/// The drawing is 360 wide and scaled to fit the width, the same way
/// `NutmegView` works in its own space. Given more height, the wall grows
/// upward (with a shelf or a window), so a quiet step isn't left with a gap.
struct KitchenStage: View {
    let scene: CookScene
    /// 0 or 1: which side Nutmeg stands on, and a couple of small differences.
    var variant = 0
    /// The recipe's emoji, served up on the plate.
    var emoji = "🍽️"
    /// The step's timer, if it has one. A running timer turns the heat up, and
    /// its time shows on the oven and microwave.
    var timer: StepTimer?
    /// Goes up by one each time a timer runs out, for a little cheer.
    var cheer = 0

    /// The smallest drawing: the counter, Nutmeg and the prop, with a strip of wall.
    static let size = CGSize(width: 360, height: 200)
    /// The tallest the wall grows, in drawing units.
    private static let tallest: CGFloat = 440

    @Environment(\.nutmegSkin) private var skin
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var nod = 0

    var body: some View {
        GeometryReader { proxy in
            let widthScale = proxy.size.width / Self.size.width
            // Fit the width; if there's height to spare, the wall grows into it.
            let scale = min(widthScale, proxy.size.height / Self.size.height)
            let height = min(Self.tallest, max(Self.size.height, proxy.size.height / scale))
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                stage(at: timeline.date, height: height)
            }
            .frame(width: Self.size.width, height: height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: Self.size.width * scale, height: height * scale, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minHeight: 150, idealHeight: 200, maxHeight: .infinity)
        .accessibilityElement()
        .accessibilityLabel(scene.accessibilityLabel)
        .task {
            // A small nod as each step begins: on it.
            try? await Task.sleep(for: .milliseconds(450))
            nod += 1
        }
    }

    // MARK: - Layout

    private var flipped: Bool { variant == 1 }
    private static let counterTop: CGFloat = 150
    /// Nutmeg is 150 wide, standing behind the counter.
    private static let nutmegWidth: CGFloat = 150
    private static let nutmegTop: CGFloat = 38
    private var nutmegCenterX: CGFloat { flipped ? Self.size.width - 108 : 108 }
    /// Where the prop sits, in the unflipped drawing.
    private static let propX: CGFloat = 244
    /// His shoulder on the side facing the prop, in the unflipped drawing.
    private static let shoulder = CGPoint(x: 138, y: 116)

    /// Everything below is drawn for the 200-high kitchen; `extra` is how much
    /// taller the wall is, so the counter, Nutmeg and the props move down by it.
    private func stage(at date: Date, height: CGFloat) -> some View {
        let t = reduceMotion ? 4.0 : date.timeIntervalSinceReferenceDate
        let level = heat(at: date)
        let extra = height - Self.size.height
        return ZStack(alignment: .topLeading) {
            Canvas { context, size in
                drawWall(context, size: size, counterTop: Self.counterTop + extra)
                drawDecor(context, extra: extra)
            }
            nutmeg(t: t)
                .offset(y: extra)
            Canvas { context, _ in
                var c = context
                c.translateBy(x: 0, y: extra)
                if flipped {
                    c.translateBy(x: Self.size.width, y: 0)
                    c.scaleBy(x: -1, y: 1)
                }
                drawCounter(c)
                let paw = drawProp(c, t: t, heat: level, date: date)
                if let paw { drawArm(c, to: paw) }
            }
        }
        .frame(width: Self.size.width, height: height)
    }

    /// How lively the scene is: busier while a timer counts down, calmer when
    /// it's paused or done.
    private func heat(at date: Date) -> Double {
        guard let timer else { return 1 }
        if timer.isRunning { return 1.6 }
        if timer.isPaused || timer.isFinished { return 0.5 }
        return 1
    }

    // MARK: - Nutmeg

    private var pose: NutmegView.Pose {
        switch scene {
        case .serve: flipped ? .leftWave : .rightWave
        case .oven, .microwave, .toast, .check, .chill: .resting
        default: .noHands
        }
    }

    private func nutmeg(t: Double) -> some View {
        // Mostly he watches what he's making; every so often he glances up at you.
        let glance = Self.pulse(t, every: 7, lasting: 1.6)
        let toward: CGFloat = flipped ? -12 : 12
        let gaze = CGSize(width: toward * (1 - glance), height: -2 * (1 - glance))
        // A quick blink now and then, and a lean in for a closer look.
        let blink = Self.pulse(t + 1.3, every: 3.7, lasting: 0.18)
        let sleepy = scene == .chill ? 0.4 : 0
        let lean = Self.pulse(t + 3, every: 9, lasting: 1.4) * (flipped ? -6 : 6)
        let height = Self.nutmegWidth * 530 / 680
        return NutmegView(pose: pose, nod: nod, cheer: cheer, showsWeather: false, hat: .chef,
                          gaze: gaze, eyelids: max(sleepy, blink))
            .frame(width: Self.nutmegWidth, height: height)
            .rotationEffect(.degrees(lean), anchor: .bottom)
            .position(x: nutmegCenterX, y: Self.nutmegTop + height / 2)
    }

    static func pulse(_ t: Double, every: Double, lasting: Double) -> Double {
        NutmegMotion.pulse(t, every: every, lasting: lasting)
    }

    private static func fraction(_ value: Double) -> Double {
        value - value.rounded(.down)
    }

    // MARK: - Room

    private func drawWall(_ c: GraphicsContext, size: CGSize, counterTop: CGFloat) {
        c.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.Palette.surface))
        // Big soft tiles, lined up from the counter so they sit the same at any height.
        var tiles = Path()
        for x in stride(from: 0.0, through: size.width, by: 40) {
            tiles.move(to: CGPoint(x: x, y: 0))
            tiles.addLine(to: CGPoint(x: x, y: counterTop))
        }
        for y in stride(from: counterTop - 40, through: 0, by: -40) {
            tiles.move(to: CGPoint(x: 0, y: y))
            tiles.addLine(to: CGPoint(x: size.width, y: y))
        }
        c.stroke(tiles, with: .color(Theme.Palette.textPrimary.opacity(0.06)), lineWidth: 2)
    }

    /// When the wall has grown, something on it: a shelf of jars, or a window.
    private func drawDecor(_ c: GraphicsContext, extra: CGFloat) {
        guard extra >= 50 else { return }
        let mid = extra * 0.5 + 6
        if variant == 0 {
            // A shelf with jars and a little plant.
            c.fill(Path(roundedRect: CGRect(x: 150, y: mid + 18, width: 190, height: 7), cornerRadius: 3.5),
                   with: .color(Kit.counterTop))
            let jars: [(CGFloat, CGFloat, Color)] = [(166, 30, Kit.carrot), (196, 24, Kit.oats), (224, 34, Kit.batter)]
            for jar in jars {
                let rect = CGRect(x: jar.0, y: mid + 18 - jar.1, width: 22, height: jar.1)
                c.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(Kit.glass))
                c.fill(Path(roundedRect: CGRect(x: rect.minX + 3, y: rect.minY + jar.1 * 0.35, width: 16, height: jar.1 * 0.6),
                            cornerRadius: 4), with: .color(jar.2))
                c.fill(Path(roundedRect: CGRect(x: rect.minX - 1, y: rect.minY - 5, width: 24, height: 6), cornerRadius: 3),
                       with: .color(Kit.crust))
            }
            c.fill(Path(roundedRect: CGRect(x: 300, y: mid + 2, width: 22, height: 16), cornerRadius: 4), with: .color(Kit.carrot))
            for angle in [-40.0, 0, 40] {
                var leaf = c
                leaf.translateBy(x: 311, y: mid + 2)
                leaf.rotate(by: .degrees(angle - 90))
                leaf.fill(Path(ellipseIn: CGRect(x: 0, y: -4, width: 18, height: 8)), with: .color(Kit.greens))
            }
        } else {
            // A window with a bit of sky, on the side away from Nutmeg.
            let window = CGRect(x: 40, y: mid - 26, width: 110, height: 56)
            c.fill(Path(roundedRect: window.insetBy(dx: -5, dy: -5), cornerRadius: 12), with: .color(Kit.counterTop))
            c.fill(Path(roundedRect: window, cornerRadius: 8), with: .color(Kit.sky))
            c.fill(Path(ellipseIn: CGRect(x: window.minX + 18, y: window.minY + 14, width: 34, height: 14)),
                   with: .color(.white.opacity(0.9)))
            c.fill(Path(ellipseIn: CGRect(x: window.minX + 34, y: window.minY + 8, width: 26, height: 16)),
                   with: .color(.white.opacity(0.9)))
            c.fill(Path(CGRect(x: window.midX - 2, y: window.minY, width: 4, height: window.height)),
                   with: .color(Kit.counterTop))
        }
    }

    private func drawCounter(_ c: GraphicsContext) {
        let width = Self.size.width
        c.fill(Path(CGRect(x: 0, y: Self.counterTop, width: width, height: 50)), with: .color(Kit.counterFront))
        c.fill(Path(roundedRect: CGRect(x: -10, y: Self.counterTop - 4, width: width + 20, height: 10),
                    cornerRadius: 5), with: .color(Kit.counterTop))
        // Cupboard doors below.
        for x in stride(from: 20.0, to: width, by: 110) {
            c.stroke(Path(roundedRect: CGRect(x: x, y: Self.counterTop + 14, width: 90, height: 50), cornerRadius: 6),
                     with: .color(Kit.counterEdge), lineWidth: 2)
            c.fill(Path(roundedRect: CGRect(x: x + 38, y: Self.counterTop + 22, width: 14, height: 4), cornerRadius: 2),
                   with: .color(Kit.counterEdge))
        }
    }

    /// An arm reaching from Nutmeg's shoulder to a paw holding something.
    private func drawArm(_ c: GraphicsContext, to paw: CGPoint) {
        var arm = Path()
        arm.move(to: Self.shoulder)
        arm.addQuadCurve(to: paw, control: CGPoint(x: (Self.shoulder.x + paw.x) / 2,
                                                  y: min(Self.shoulder.y, paw.y) - 6))
        c.stroke(arm, with: .color(skin.body), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        c.fill(Kit.circle(paw, 7.5), with: .color(skin.body))
        for dx in [-3.0, 0, 3] {
            c.fill(Kit.circle(CGPoint(x: paw.x + dx, y: paw.y - 3.5 + abs(dx) * 0.3), 1.3), with: .color(skin.foot))
        }
    }

    // MARK: - Props

    /// Draws the scene's prop, and returns where Nutmeg's paw should be if
    /// he's holding something.
    private func drawProp(_ c: GraphicsContext, t: Double, heat: Double, date: Date) -> CGPoint? {
        let x = Self.propX
        switch scene {
        case .boil: return drawBoil(c, x: x, t: t, heat: heat)
        case .fry: return drawFry(c, x: x, t: t, heat: heat)
        case .oven: drawOven(c, x: x, t: t, heat: heat, date: date); return nil
        case .microwave: drawMicrowave(c, x: x, t: t, heat: heat, date: date); return nil
        case .kettle: return drawKettle(c, x: x, t: t, heat: heat)
        case .toast: drawToaster(c, x: x, t: t, heat: heat); return nil
        case .chop: return drawChop(c, x: x, t: t, heat: heat)
        case .mix: return drawMix(c, x: x, t: t, heat: heat)
        case .serve: drawServe(c, x: x, t: t); return nil
        case .check: drawCheck(c, x: x, t: t); return nil
        case .chill: drawChill(c, x: x, t: t); return nil
        case .prep: return drawPrep(c, x: x, t: t)
        }
    }

    /// A gas ring with flames that flicker harder as the heat goes up.
    private func drawHob(_ c: GraphicsContext, x: CGFloat, t: Double, heat: Double) {
        c.fill(Path(roundedRect: CGRect(x: x - 52, y: 142, width: 104, height: 8), cornerRadius: 4),
               with: .color(Kit.dark))
        for i in 0..<4 {
            let fx = x - 30 + CGFloat(i) * 20
            let flicker = 1 + 0.25 * sin(t * 12 + Double(i) * 1.7) * heat
            let tall = CGFloat(6 + 5 * heat * flicker)
            c.fill(Kit.flame(base: CGPoint(x: fx, y: 143), height: tall, width: 7), with: .color(Kit.flameOuter))
            c.fill(Kit.flame(base: CGPoint(x: fx, y: 143), height: tall * 0.55, width: 4), with: .color(Kit.flameInner))
        }
    }

    /// Soft wisps of steam rising from `origin`.
    private func drawSteam(_ c: GraphicsContext, origin: CGPoint, spread: CGFloat, t: Double, heat: Double,
                           count: Int = 3, rise: CGFloat = 60) {
        for k in 0..<count {
            let phase = Self.fraction(t * 0.28 * (0.6 + 0.4 * heat) + Double(k) / Double(count))
            let baseX = origin.x - spread / 2 + spread * CGFloat(k) / CGFloat(max(1, count - 1))
            let y = origin.y - CGFloat(phase) * rise
            let sway = CGFloat(sin(t * 1.5 + Double(k) * 2)) * 6
            var wisp = Path()
            wisp.move(to: CGPoint(x: baseX + sway, y: y + 9))
            wisp.addQuadCurve(to: CGPoint(x: baseX - sway, y: y - 9), control: CGPoint(x: baseX + sway * 2, y: y))
            c.stroke(wisp, with: .color(.white.opacity(sin(phase * .pi) * 0.85)),
                     style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
    }

    private var metal: Color { variant == 1 ? Kit.copper : Kit.castIron }

    private func drawBoil(_ c: GraphicsContext, x: CGFloat, t: Double, heat: Double) -> CGPoint {
        drawHob(c, x: x, t: t, heat: heat)
        // Handles, then the pot, then the rim and the water.
        for side in [-1.0, 1.0] {
            c.fill(Path(roundedRect: CGRect(x: x + side * 48 - 8, y: 98, width: 16, height: 7), cornerRadius: 3.5),
                   with: .color(metal))
        }
        c.fill(Path(roundedRect: CGRect(x: x - 42, y: 92, width: 84, height: 52), cornerRadius: 9),
               with: .color(metal))
        c.fill(Path(roundedRect: CGRect(x: x - 34, y: 100, width: 8, height: 36), cornerRadius: 4),
               with: .color(.white.opacity(0.18)))
        c.fill(Path(ellipseIn: CGRect(x: x - 46, y: 86, width: 92, height: 13)), with: .color(Kit.rim))
        c.fill(Path(ellipseIn: CGRect(x: x - 40, y: 88, width: 80, height: 9)), with: .color(Kit.water))
        // Bubbles that grow and pop.
        let bubbles = Int(3 + 4 * heat)
        for i in 0..<bubbles {
            let phase = Self.fraction(t * 0.9 * heat + Double(i) * 0.37)
            let bx = x - 30 + CGFloat(Self.fraction(Double(i) * 0.618)) * 60
            let r = CGFloat(1.5 + 3 * phase)
            c.stroke(Kit.circle(CGPoint(x: bx, y: 92 - CGFloat(phase) * 3), r),
                     with: .color(.white.opacity(1 - phase)), lineWidth: 1.5)
        }
        drawSteam(c, origin: CGPoint(x: x, y: 78), spread: 44, t: t, heat: heat)
        // A wooden spoon going round.
        let angle = t * 2.2 * heat
        let tip = CGPoint(x: x + 20 * CGFloat(cos(angle)), y: 92 + 3 * CGFloat(sin(angle)))
        let paw = CGPoint(x: tip.x - 40, y: tip.y - 32)
        Kit.utensil(c, from: tip, to: paw, color: Kit.wood)
        return paw
    }

    private func drawFry(_ c: GraphicsContext, x: CGFloat, t: Double, heat: Double) -> CGPoint {
        drawHob(c, x: x, t: t, heat: heat)
        // Every few seconds, a little toss.
        let toss = Self.pulse(t, every: 4.5, lasting: 0.7)
        c.fill(Path(roundedRect: CGRect(x: x + 30, y: 127, width: 58, height: 7), cornerRadius: 3.5),
               with: .color(Kit.dark))
        c.fill(Path(roundedRect: CGRect(x: x - 46, y: 126, width: 82, height: 18), cornerRadius: 8),
               with: .color(metal))
        c.fill(Path(ellipseIn: CGRect(x: x - 48, y: 120, width: 86, height: 12)), with: .color(Kit.rim))
        c.fill(Path(ellipseIn: CGRect(x: x - 42, y: 122, width: 74, height: 8)), with: .color(Kit.panInside))
        // What's in the pan, jumping in the heat.
        let bits: [(CGFloat, Color)] = [(-26, Kit.egg), (-12, Kit.greens), (2, Kit.carrot), (16, Kit.egg), (-4, Kit.carrot)]
        for (i, bit) in bits.enumerated() {
            let jiggle = abs(sin(t * 9 + Double(i) * 1.3)) * 1.5 * heat
            let lift = CGFloat(toss * (18 + Double(i % 3) * 5) + jiggle)
            c.fill(Path(ellipseIn: CGRect(x: x + bit.0 - 5, y: 122 - lift, width: 10, height: 6)), with: .color(bit.1))
        }
        // Sizzle.
        for i in 0..<Int(4 + 6 * heat) {
            let phase = Self.fraction(t * 1.6 + Double(i) * 0.29)
            let sx = x - 36 + CGFloat(Self.fraction(Double(i) * 0.71)) * 64
            c.fill(Kit.circle(CGPoint(x: sx, y: 120 - CGFloat(phase) * 18), 1.3),
                   with: .color(Kit.flameInner.opacity(1 - phase)))
        }
        drawSteam(c, origin: CGPoint(x: x - 6, y: 106), spread: 40, t: t, heat: heat * 0.7, count: 2, rise: 44)
        // A spatula pushing things round.
        let head = CGPoint(x: x - 12 + 14 * CGFloat(sin(t * 2.4 * heat)), y: 123)
        let paw = CGPoint(x: head.x - 34, y: head.y - 30)
        Kit.utensil(c, from: head, to: paw, color: Kit.dark)
        c.fill(Path(roundedRect: CGRect(x: head.x - 8, y: head.y - 3, width: 16, height: 5), cornerRadius: 2),
               with: .color(Kit.dark))
        return paw
    }

    private func drawOven(_ c: GraphicsContext, x: CGFloat, t: Double, heat: Double, date: Date) {
        // Heat shimmer above.
        for i in 0..<3 {
            var line = Path()
            let lx = x - 30 + CGFloat(i) * 30
            let wobble = CGFloat(sin(t * 3 + Double(i))) * 3
            line.move(to: CGPoint(x: lx, y: 58))
            line.addCurve(to: CGPoint(x: lx, y: 34), control1: CGPoint(x: lx + 6 + wobble, y: 50),
                          control2: CGPoint(x: lx - 6 - wobble, y: 42))
            c.stroke(line, with: .color(Kit.flameOuter.opacity(0.25 * heat)),
                     style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        c.fill(Path(roundedRect: CGRect(x: x - 60, y: 64, width: 120, height: 86), cornerRadius: 12),
               with: .color(Kit.appliance))
        c.fill(Path(roundedRect: CGRect(x: x - 60, y: 64, width: 120, height: 16), cornerRadius: 8),
               with: .color(Kit.applianceEdge))
        for i in 0..<3 {
            c.fill(Kit.circle(CGPoint(x: x - 46 + CGFloat(i) * 13, y: 72), 3.5), with: .color(Kit.dark))
        }
        drawDisplay(c, rect: CGRect(x: x + 12, y: 67, width: 40, height: 11), date: date, fallback: "180°")
        c.fill(Path(roundedRect: CGRect(x: x - 34, y: 84, width: 68, height: 4), cornerRadius: 2), with: .color(Kit.dark))
        let window = CGRect(x: x - 46, y: 92, width: 92, height: 50)
        c.fill(Path(roundedRect: window, cornerRadius: 8), with: .color(Kit.dark))
        let glow = 0.35 + 0.15 * sin(t * 2) * heat
        c.fill(Path(roundedRect: window.insetBy(dx: 3, dy: 3), cornerRadius: 6),
               with: .color(Kit.flameOuter.opacity(glow)))
        // Something in a dish, browning.
        c.fill(Path(roundedRect: CGRect(x: x - 26, y: 124, width: 52, height: 10), cornerRadius: 4), with: .color(Kit.dish))
        c.fill(Path(ellipseIn: CGRect(x: x - 22, y: 116, width: 44, height: 12)), with: .color(Kit.toast))
    }

    private func drawMicrowave(_ c: GraphicsContext, x: CGFloat, t: Double, heat: Double, date: Date) {
        c.fill(Path(roundedRect: CGRect(x: x - 64, y: 76, width: 124, height: 74), cornerRadius: 10),
               with: .color(Kit.appliance))
        let window = CGRect(x: x - 56, y: 84, width: 76, height: 58)
        c.fill(Path(roundedRect: window, cornerRadius: 6), with: .color(Kit.dark))
        let hum = 0.3 + 0.1 * sin(t * 5) * heat
        c.fill(Path(roundedRect: window.insetBy(dx: 3, dy: 3), cornerRadius: 5),
               with: .color(Kit.flameInner.opacity(hum)))
        // The plate going round, and the bowl on it.
        c.fill(Path(ellipseIn: CGRect(x: x - 46, y: 128, width: 56, height: 8)), with: .color(Kit.rim))
        let turn = t * 1.3 * min(heat, 1.2)
        let bx = x - 18 + 12 * CGFloat(cos(turn))
        let depth = 1 - 0.15 * CGFloat(sin(turn))
        var bowl = Path()
        bowl.move(to: CGPoint(x: bx - 14 * depth, y: 118))
        bowl.addQuadCurve(to: CGPoint(x: bx + 14 * depth, y: 118), control: CGPoint(x: bx, y: 142))
        bowl.closeSubpath()
        c.fill(bowl, with: .color(Kit.bowl))
        c.fill(Path(ellipseIn: CGRect(x: bx - 14 * depth, y: 115, width: 28 * depth, height: 6)), with: .color(Kit.batter))
        // The panel.
        drawDisplay(c, rect: CGRect(x: x + 26, y: 88, width: 28, height: 12), date: date, fallback: "1:30")
        for row in 0..<3 {
            for col in 0..<2 {
                c.fill(Kit.circle(CGPoint(x: x + 33 + CGFloat(col) * 14, y: 110 + CGFloat(row) * 11), 3.5),
                       with: .color(Kit.applianceEdge))
            }
        }
    }

    /// The little amber readout on the oven and microwave: the step's timer
    /// when it has one.
    private func drawDisplay(_ c: GraphicsContext, rect: CGRect, date: Date, fallback: String) {
        c.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(Kit.dark))
        let text = timer.map { ClockText.text(seconds: Int(ceil($0.remaining(at: date)))) } ?? fallback
        var label = c
        let center = CGPoint(x: rect.midX, y: rect.midY)
        if flipped {
            // Keep the digits the right way round when the scene is mirrored.
            label.translateBy(x: center.x, y: 0)
            label.scaleBy(x: -1, y: 1)
            label.translateBy(x: -center.x, y: 0)
        }
        label.draw(Text(text).font(.system(size: 8, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Kit.flameInner), at: center)
    }

    private func drawKettle(_ c: GraphicsContext, x: CGFloat, t: Double, heat: Double) -> CGPoint {
        c.fill(Path(ellipseIn: CGRect(x: x - 38, y: 142, width: 76, height: 9)), with: .color(Kit.dark))
        var body = c
        // A little rattle as it comes to the boil.
        let rattle = sin(t * 30) * 1.2 * max(0, heat - 0.8)
        body.translateBy(x: x, y: 146)
        body.rotate(by: .degrees(rattle))
        body.translateBy(x: -x, y: -146)
        let enamel = variant == 1 ? Kit.copper : Kit.enamel
        var spout = Path()
        spout.move(to: CGPoint(x: x + 26, y: 124))
        spout.addLine(to: CGPoint(x: x + 50, y: 98))
        body.stroke(spout, with: .color(enamel), style: StrokeStyle(lineWidth: 9, lineCap: .round))
        var handle = Path()
        handle.move(to: CGPoint(x: x - 28, y: 100))
        handle.addQuadCurve(to: CGPoint(x: x - 28, y: 134), control: CGPoint(x: x - 54, y: 117))
        body.stroke(handle, with: .color(Kit.dark), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        body.fill(Path(roundedRect: CGRect(x: x - 32, y: 90, width: 64, height: 56), cornerRadius: 18),
                  with: .color(enamel))
        body.fill(Path(ellipseIn: CGRect(x: x - 24, y: 84, width: 48, height: 12)), with: .color(Kit.applianceEdge))
        body.fill(Kit.circle(CGPoint(x: x, y: 83), 5), with: .color(Kit.dark))
        body.fill(Path(roundedRect: CGRect(x: x - 22, y: 100, width: 7, height: 30), cornerRadius: 3.5),
                  with: .color(.white.opacity(0.3)))
        // Puffs of steam from the spout.
        let spoutTip = CGPoint(x: x + 52, y: 94)
        for i in 0..<5 {
            let phase = Self.fraction(t * 0.6 * heat + Double(i) / 5)
            let p = CGPoint(x: spoutTip.x + CGFloat(phase) * 12 + CGFloat(sin(t * 2 + Double(i))) * 3,
                            y: spoutTip.y - CGFloat(phase) * 52)
            c.fill(Kit.circle(p, CGFloat(3 + phase * 9)), with: .color(.white.opacity((1 - phase) * 0.8)))
        }
        return CGPoint(x: x - 50, y: 117)
    }

    private func drawToaster(_ c: GraphicsContext, x: CGFloat, t: Double, heat: Double) {
        // Every few seconds the toast pops up.
        let pop = Self.pulse(t, every: 4, lasting: 0.8)
        let lift = CGFloat(4 + 26 * pop)
        for slot in [-19.0, 19.0] {
            let slice = CGRect(x: x + slot - 12, y: 100 - lift, width: 24, height: 30)
            c.fill(Path(roundedRect: slice, cornerRadius: 7), with: .color(Kit.crust))
            c.fill(Path(roundedRect: slice.insetBy(dx: 3, dy: 3), cornerRadius: 5), with: .color(Kit.toast))
        }
        c.fill(Path(roundedRect: CGRect(x: x - 46, y: 100, width: 92, height: 48), cornerRadius: 14),
               with: .color(Kit.chrome))
        for slot in [-19.0, 19.0] {
            c.fill(Path(roundedRect: CGRect(x: x + slot - 14, y: 99, width: 28, height: 5), cornerRadius: 2.5),
                   with: .color(Kit.dark))
            if pop < 0.2 {
                c.fill(Path(roundedRect: CGRect(x: x + slot - 12, y: 100, width: 24, height: 2), cornerRadius: 1),
                       with: .color(Kit.flameOuter.opacity(0.5 * heat)))
            }
        }
        c.fill(Path(roundedRect: CGRect(x: x - 34, y: 112, width: 8, height: 26), cornerRadius: 4),
               with: .color(.white.opacity(0.35)))
        // The lever, down while it's toasting.
        let lever = CGFloat(118 + 14 * (1 - pop))
        c.fill(Path(roundedRect: CGRect(x: x + 44, y: lever - 3, width: 10, height: 6), cornerRadius: 3), with: .color(Kit.dark))
        // A few crumbs sparkle as it pops.
        if pop > 0.3 {
            for i in 0..<4 {
                let a = Double(i) * 1.6 + t
                Kit.sparkle(c, at: CGPoint(x: x + CGFloat(cos(a)) * 40, y: 78 - lift / 2 + CGFloat(sin(a)) * 10),
                            size: 4 * pop, color: Kit.flameInner)
            }
        }
    }

    private func drawChop(_ c: GraphicsContext, x: CGFloat, t: Double, heat: Double) -> CGPoint {
        c.fill(Path(roundedRect: CGRect(x: x - 70, y: 138, width: 132, height: 10), cornerRadius: 5), with: .color(Kit.board))
        c.fill(Path(roundedRect: CGRect(x: x - 70, y: 145, width: 132, height: 5), cornerRadius: 2.5),
               with: .color(Kit.boardEdge))
        // Slices pile up as the carrot gets shorter, then it starts again.
        let slices = Int(Self.fraction(t / 6) * 7)
        let cut = x - 10 + CGFloat(slices) * 5
        for i in 0..<slices {
            let sx = x - 58 + CGFloat(i) * 6
            c.fill(Path(ellipseIn: CGRect(x: sx, y: 130 + CGFloat(i % 2), width: 9, height: 9)), with: .color(Kit.carrot))
            c.fill(Kit.circle(CGPoint(x: sx + 4.5, y: 134.5 + CGFloat(i % 2)), 2), with: .color(Kit.egg))
        }
        c.fill(Path(roundedRect: CGRect(x: cut, y: 126, width: x + 44 - cut, height: 12), cornerRadius: 6),
               with: .color(Kit.carrot))
        for (i, angle) in [-30.0, 0, 30].enumerated() {
            var leaf = c
            leaf.translateBy(x: x + 46, y: 132)
            leaf.rotate(by: .degrees(angle))
            leaf.fill(Path(ellipseIn: CGRect(x: 0, y: -3, width: 14 + CGFloat(i % 2) * 3, height: 6)), with: .color(Kit.greens))
        }
        // The knife comes down, again and again.
        let lift = CGFloat(max(0, sin(t * 6 * max(1, heat)))) * 10
        var blade = Path()
        blade.move(to: CGPoint(x: cut - 26, y: 116 - lift))
        blade.addLine(to: CGPoint(x: cut + 3, y: 116 - lift))
        blade.addLine(to: CGPoint(x: cut + 3, y: 137 - lift))
        blade.addQuadCurve(to: CGPoint(x: cut - 26, y: 128 - lift), control: CGPoint(x: cut - 16, y: 137 - lift))
        blade.closeSubpath()
        c.fill(blade, with: .color(Kit.chrome))
        c.fill(Path(roundedRect: CGRect(x: cut - 50, y: 116 - lift, width: 26, height: 8), cornerRadius: 4),
               with: .color(Kit.dark))
        return CGPoint(x: cut - 46, y: 120 - lift)
    }

    private func drawMix(_ c: GraphicsContext, x: CGFloat, t: Double, heat: Double) -> CGPoint {
        var bowl = Path()
        bowl.move(to: CGPoint(x: x - 48, y: 114))
        bowl.addQuadCurve(to: CGPoint(x: x + 48, y: 114), control: CGPoint(x: x, y: 172))
        bowl.closeSubpath()
        c.fill(bowl, with: .color(variant == 1 ? Kit.enamel : Kit.bowl))
        c.stroke(bowl, with: .color(Kit.applianceEdge), lineWidth: 2)
        c.fill(Path(ellipseIn: CGRect(x: x - 48, y: 108, width: 96, height: 13)), with: .color(Kit.applianceEdge))
        c.fill(Path(ellipseIn: CGRect(x: x - 42, y: 110, width: 84, height: 9)), with: .color(Kit.batter))
        // A whisk going round, flicking the odd drop.
        let angle = t * 3 * heat
        let tip = CGPoint(x: x + 22 * CGFloat(cos(angle)), y: 113 + 3 * CGFloat(sin(angle)))
        let paw = CGPoint(x: tip.x - 38, y: tip.y - 36)
        Kit.utensil(c, from: CGPoint(x: tip.x - 5, y: tip.y - 10), to: paw, color: Kit.dark)
        for w in [5.0, 9, 13] {
            c.stroke(Path(ellipseIn: CGRect(x: tip.x - w / 2 - 3, y: tip.y - 16, width: w, height: 18)),
                     with: .color(Kit.chrome), lineWidth: 1.5)
        }
        let flick = Self.pulse(t, every: 2.3, lasting: 0.5)
        if flick > 0 {
            for i in 0..<3 {
                c.fill(Kit.circle(CGPoint(x: x + 30 + CGFloat(i) * 6, y: 106 - CGFloat(flick) * (10 + CGFloat(i) * 5)), 1.8),
                       with: .color(Kit.batter))
            }
        }
        return paw
    }

    private func drawServe(_ c: GraphicsContext, x: CGFloat, t: Double) {
        c.fill(Path(ellipseIn: CGRect(x: x - 56, y: 130, width: 112, height: 18)), with: .color(Kit.applianceEdge))
        c.fill(Path(ellipseIn: CGRect(x: x - 54, y: 128, width: 108, height: 16)), with: .color(Kit.plate))
        c.stroke(Path(ellipseIn: CGRect(x: x - 38, y: 131, width: 76, height: 10)), with: .color(Kit.applianceEdge), lineWidth: 1)
        var label = c
        if flipped {
            label.translateBy(x: x, y: 0)
            label.scaleBy(x: -1, y: 1)
            label.translateBy(x: -x, y: 0)
        }
        let bob = CGFloat(sin(t * 2)) * 1.5
        label.draw(Text(emoji).font(.system(size: 48)), at: CGPoint(x: x, y: 118 + bob))
        drawSteam(c, origin: CGPoint(x: x, y: 82), spread: 36, t: t, heat: 1, count: 3, rise: 40)
        for i in 0..<5 {
            let a = Double(i) * 1.26
            let twinkle = max(0, sin(t * 2.2 + Double(i) * 1.7))
            Kit.sparkle(c, at: CGPoint(x: x + CGFloat(cos(a)) * 64, y: 100 + CGFloat(sin(a)) * 34),
                        size: 6 * twinkle, color: Kit.flameInner)
        }
    }

    private func drawCheck(_ c: GraphicsContext, x: CGFloat, t: Double) {
        c.fill(Path(ellipseIn: CGRect(x: x - 50, y: 132, width: 100, height: 15)), with: .color(Kit.plate))
        c.fill(Path(roundedRect: CGRect(x: x - 30, y: 120, width: 52, height: 20), cornerRadius: 10), with: .color(Kit.crust))
        c.fill(Path(roundedRect: CGRect(x: x - 26, y: 122, width: 44, height: 10), cornerRadius: 5), with: .color(Kit.toast))
        // The probe goes in, the needle climbs, and it's done.
        let reading = reduceMotion ? 1 : min(1, Self.fraction(t / 6) * 1.6)
        var probe = Path()
        probe.move(to: CGPoint(x: x + 2, y: 128))
        probe.addLine(to: CGPoint(x: x + 26, y: 88))
        c.stroke(probe, with: .color(Kit.chrome), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        let dial = CGPoint(x: x + 30, y: 80)
        c.fill(Kit.circle(dial, 17), with: .color(Kit.applianceEdge))
        c.fill(Kit.circle(dial, 15), with: .color(Kit.plate))
        var zone = Path()
        zone.addArc(center: dial, radius: 11, startAngle: .degrees(-20), endAngle: .degrees(20), clockwise: false)
        c.stroke(zone, with: .color(Theme.Palette.sage), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        let angle = Angle.degrees(-200 + 200 * reading)
        var needle = Path()
        needle.move(to: dial)
        needle.addLine(to: CGPoint(x: dial.x + 11 * CGFloat(cos(angle.radians)), y: dial.y + 11 * CGFloat(sin(angle.radians))))
        c.stroke(needle, with: .color(Kit.dark), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        c.fill(Kit.circle(dial, 2), with: .color(Kit.dark))
        if reading >= 1 {
            let badge = CGPoint(x: dial.x + 28, y: dial.y - 16)
            c.fill(Kit.circle(badge, 11), with: .color(Theme.Palette.sage))
            var tick = Path()
            tick.move(to: CGPoint(x: badge.x - 5, y: badge.y))
            tick.addLine(to: CGPoint(x: badge.x - 1, y: badge.y + 4))
            tick.addLine(to: CGPoint(x: badge.x + 5, y: badge.y - 4))
            c.stroke(tick, with: .color(.white), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }

    private func drawChill(_ c: GraphicsContext, x: CGFloat, t: Double) {
        let jar = CGRect(x: x - 28, y: 92, width: 56, height: 56)
        c.fill(Path(roundedRect: jar, cornerRadius: 10), with: .color(Kit.glass))
        c.fill(Path(roundedRect: CGRect(x: x - 24, y: 118, width: 48, height: 26), cornerRadius: 7), with: .color(Kit.oats))
        c.fill(Path(roundedRect: CGRect(x: x - 24, y: 110, width: 48, height: 10), cornerRadius: 4), with: .color(Kit.batter))
        c.stroke(Path(roundedRect: jar, cornerRadius: 10), with: .color(Kit.glassEdge), lineWidth: 2)
        c.fill(Path(roundedRect: CGRect(x: x - 30, y: 84, width: 60, height: 10), cornerRadius: 4), with: .color(skin.foot))
        c.fill(Path(roundedRect: CGRect(x: x - 20, y: 98, width: 6, height: 40), cornerRadius: 3), with: .color(.white.opacity(0.5)))
        // Slow snowflakes, drifting down.
        for i in 0..<9 {
            let phase = Self.fraction(t * 0.12 + Double(i) * 0.113)
            let fx = x - 70 + CGFloat(Self.fraction(Double(i) * 0.618)) * 140 + CGFloat(sin(t + Double(i))) * 6
            Kit.sparkle(c, at: CGPoint(x: fx, y: 10 + CGFloat(phase) * 130), size: 4, color: Kit.frost)
        }
    }

    private func drawPrep(_ c: GraphicsContext, x: CGFloat, t: Double) -> CGPoint {
        // A recipe card, held up and read, with the odd page turn.
        let turn = Self.pulse(t, every: 5, lasting: 0.6)
        var card = c
        card.translateBy(x: x - 6, y: 104)
        card.rotate(by: .degrees(-6))
        card.scaleBy(x: CGFloat(1 - 0.7 * turn), y: 1)
        let rect = CGRect(x: -34, y: -42, width: 68, height: 84)
        card.fill(Path(roundedRect: rect.offsetBy(dx: 2, dy: 3), cornerRadius: 8), with: .color(Kit.applianceEdge))
        card.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(Kit.plate))
        card.fill(Path(roundedRect: CGRect(x: -24, y: -32, width: 36, height: 6), cornerRadius: 3), with: .color(Kit.flameOuter))
        for row in 0..<5 {
            card.fill(Path(roundedRect: CGRect(x: -24, y: -16 + CGFloat(row) * 10, width: row == 4 ? 26 : 46, height: 4),
                           cornerRadius: 2), with: .color(Theme.Palette.textPrimary.opacity(0.15)))
        }
        return CGPoint(x: x - 42, y: 112)
    }
}

/// Colors and small shapes for the kitchen. The room's own colors come from
/// the theme; these are the things in it.
private enum Kit {
    static func hex(_ value: UInt32) -> Color {
        Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
              blue: Double(value & 0xFF) / 255)
    }

    static let counterTop = hex(0xD9A56A)
    static let counterFront = hex(0xE8C193)
    static let counterEdge = hex(0xC99A62)
    static let dark = hex(0x3B2A1A)
    static let castIron = hex(0x5A4636)
    static let copper = hex(0xC77A3F)
    static let rim = hex(0x8A7461)
    static let water = hex(0xCFE3E8)
    static let panInside = hex(0x4A3A2C)
    static let flameOuter = hex(0xF0A83A)
    static let flameInner = hex(0xFFD66B)
    static let egg = hex(0xFFF1C9)
    static let greens = hex(0x6E9A4E)
    static let carrot = hex(0xE8893A)
    static let wood = hex(0xB9804A)
    static let appliance = hex(0xF4EDE2)
    static let applianceEdge = hex(0xDCCFBF)
    static let enamel = hex(0xF7F1E8)
    static let chrome = hex(0xD5D9DE)
    static let toast = hex(0xE3A857)
    static let crust = hex(0xB87A3A)
    static let dish = hex(0x8A5A3A)
    static let bowl = hex(0xFFF6EA)
    static let batter = hex(0xF6D28B)
    static let plate = hex(0xFFFDF9)
    static let board = hex(0xE2B983)
    static let boardEdge = hex(0xC99A62)
    static let glass = hex(0xE7F3F7)
    static let glassEdge = hex(0xB9D3DC)
    static let oats = hex(0xF3E3C6)
    static let frost = hex(0xBFE0EE)
    static let sky = hex(0xCDE6F2)

    static func circle(_ center: CGPoint, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
    }

    /// A teardrop flame standing on `base`.
    static func flame(base: CGPoint, height: CGFloat, width: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: base.x - width / 2, y: base.y))
        p.addQuadCurve(to: CGPoint(x: base.x, y: base.y - height), control: CGPoint(x: base.x - width / 2, y: base.y - height * 0.5))
        p.addQuadCurve(to: CGPoint(x: base.x + width / 2, y: base.y), control: CGPoint(x: base.x + width / 2, y: base.y - height * 0.5))
        p.closeSubpath()
        return p
    }

    /// A spoon or spatula handle from what it's touching up to the paw.
    static func utensil(_ c: GraphicsContext, from tip: CGPoint, to handle: CGPoint, color: Color) {
        var p = Path()
        p.move(to: tip)
        p.addLine(to: handle)
        c.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 4, lineCap: .round))
    }

    /// A four-pointed twinkle.
    static func sparkle(_ c: GraphicsContext, at center: CGPoint, size: CGFloat, color: Color) {
        guard size > 0.2 else { return }
        var p = Path()
        p.move(to: CGPoint(x: center.x, y: center.y - size))
        p.addQuadCurve(to: CGPoint(x: center.x + size, y: center.y), control: center)
        p.addQuadCurve(to: CGPoint(x: center.x, y: center.y + size), control: center)
        p.addQuadCurve(to: CGPoint(x: center.x - size, y: center.y), control: center)
        p.addQuadCurve(to: CGPoint(x: center.x, y: center.y - size), control: center)
        c.fill(p, with: .color(color))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(CookScene.allCases, id: \.self) { scene in
                KitchenStage(scene: scene, variant: scene.rawValue.count % 2, emoji: "🍝")
            }
        }
        .padding()
    }
    .background(Theme.Palette.background)
}
