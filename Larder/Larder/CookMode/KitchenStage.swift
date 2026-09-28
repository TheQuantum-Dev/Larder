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
    /// 0, 1 or 2: which side Nutmeg stands on, and a few small differences, so
    /// two steps in a row with the same scene don't look the same.
    var variant = 0
    /// What's on the chopping board.
    var produce = CookScene.Produce.carrot
    /// The recipe's emoji, served up on the plate.
    var emoji = "🍽️"
    /// The step's timer, if it has one. A running timer turns the heat up, and
    /// its time shows on the oven and microwave.
    var timer: StepTimer?
    /// Goes up by one each time a timer runs out, for a little cheer.
    var cheer = 0
    /// Said in a speech bubble on each cheer, instead of the "!" that marks
    /// a timer going off. For the done screen: "Enjoy!" and friends.
    var cheerLine: String?

    /// The smallest drawing: the counter, Nutmeg and the prop, with a strip of wall.
    static let size = CGSize(width: 360, height: 200)
    /// The tallest the wall grows, in drawing units.
    private static let tallest: CGFloat = 440

    @Environment(\.nutmegSkin) private var skin
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var nod = 0
    /// When the step's timer last went off, for his "oh!" face.
    @State private var surprisedAt: Date?

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
        .onChange(of: cheer) { _, _ in surprisedAt = .now }
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
            nutmeg(t: t, date: date)
                .offset(y: extra)
            if let cheerLine, isSpeaking(at: date) {
                SpeechBubble(text: cheerLine, pointsLeft: !flipped)
                    .fixedSize()
                    .position(x: nutmegCenterX + (flipped ? -104 : 104), y: Self.nutmegTop + extra + 6)
                    .transition(.scale(scale: 0.6, anchor: flipped ? .trailing : .leading).combined(with: .opacity))
            } else if cheerLine == nil, isSurprised(at: date) {
                surpriseMark
                    .position(x: nutmegCenterX + (flipped ? -52 : 52), y: Self.nutmegTop + extra - 4)
            }
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

    /// The "oh!" lasts a moment after a timer goes off.
    /// The speech bubble stays up long enough to read.
    private func isSpeaking(at date: Date) -> Bool {
        guard let surprisedAt else { return false }
        return date.timeIntervalSince(surprisedAt) < 3.5
    }

    private func isSurprised(at date: Date) -> Bool {
        guard let surprisedAt else { return false }
        return date.timeIntervalSince(surprisedAt) < 1.2
    }

    private func nutmeg(t: Double, date: Date) -> some View {
        let toward: CGFloat = flipped ? -12 : 12
        // Mostly he watches what he's making; every so often he glances up at you.
        let glance = Self.pulse(t, every: 7, lasting: 1.6)
        var gaze = CGSize(width: toward * (1 - glance), height: -2 * (1 - glance))
        if let timer, timer.isRunning, timer.remaining(at: date) <= 10 {
            // The last few seconds: eyes on the pot.
            gaze = CGSize(width: toward * 1.3, height: 4)
        } else if timer?.isFinished == true {
            // Time's up: he looks at you.
            gaze = .zero
        }
        // A quick blink now and then, and a lean in for a closer look.
        let blink = Self.pulse(t + 1.3, every: 3.7, lasting: 0.18)
        let sleepy = scene == .chill ? 0.4 : 0
        let lean = Self.pulse(t + 3, every: 9, lasting: 1.4) * (flipped ? -6 : 6)
        let height = Self.nutmegWidth * 530 / 680
        let surprised = cheerLine == nil && isSurprised(at: date)
        return NutmegView(pose: pose, nod: nod, cheer: cheer, showsWeather: false, hat: .chef,
                          gaze: gaze, eyelids: surprised ? 0 : max(sleepy, blink),
                          expression: surprised ? .surprised : .smile,
                          apron: apronTrim,
                          goggles: scene == .chop && produce == .onion,
                          mitts: scene == .oven ? Kit.mitt : nil)
            .frame(width: Self.nutmegWidth, height: height)
            .rotationEffect(.degrees(lean), anchor: .bottom)
            .position(x: nutmegCenterX, y: Self.nutmegTop + height / 2)
    }

    /// The apron's trim follows the look, except where the look's color is
    /// his own body color (amber, coral, harvest): then it's sage, so it shows.
    private var apronTrim: Color {
        ThemeStore.shared.look == .snow ? Theme.Palette.amber : Theme.Palette.sage
    }

    /// A little "!" beside his hat when a timer goes off.
    private var surpriseMark: some View {
        Text("!")
            .font(.system(size: 18, weight: .black, design: .rounded))
            .foregroundStyle(Kit.dark)
            .frame(width: 26, height: 26)
            .background(Kit.flameInner, in: Circle())
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
        if variant == 2 {
            // A wall clock, and a rail of hanging spoons.
            let clock = CGPoint(x: 290, y: mid)
            c.fill(Kit.circle(clock, 22), with: .color(Kit.counterTop))
            c.fill(Kit.circle(clock, 18), with: .color(Kit.plate))
            var hands = Path()
            hands.move(to: CGPoint(x: clock.x, y: clock.y - 12))
            hands.addLine(to: clock)
            hands.addLine(to: CGPoint(x: clock.x + 9, y: clock.y + 3))
            c.stroke(hands, with: .color(Kit.dark), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            c.fill(Path(roundedRect: CGRect(x: 170, y: mid - 20, width: 80, height: 5), cornerRadius: 2.5),
                   with: .color(Kit.chrome))
            for (i, color) in [Kit.wood, Kit.chrome, Kit.wood].enumerated() {
                let hx = 184 + CGFloat(i) * 26
                c.fill(Path(roundedRect: CGRect(x: hx - 2, y: mid - 16, width: 4, height: 30), cornerRadius: 2), with: .color(color))
                c.fill(Path(ellipseIn: CGRect(x: hx - 6, y: mid + 12, width: 12, height: 14)), with: .color(color))
            }
        } else if variant == 0 {
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
        case .drain: return drawDrain(c, x: x, t: t, heat: heat)
        case .crack: return drawCrack(c, x: x, t: t)
        case .season: return drawSeason(c, x: x, t: t)
        case .spread: return drawSpread(c, x: x, t: t)
        case .mash: return drawMash(c, x: x, t: t, heat: heat)
        case .whisk: return drawWhisk(c, x: x, t: t, heat: heat)
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

    private var bowlColor: Color { [Kit.bowl, Kit.enamel, Kit.sageBowl][variant % 3] }

    private var metal: Color { [Kit.castIron, Kit.copper, Kit.blueEnamel][variant % 3] }

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
        if variant == 2 {
            // Every so often, a taste: the spoon comes up out of the pot.
            let taste = Self.pulse(t, every: 5, lasting: 1.8)
            let stir = CGPoint(x: x + 14 * CGFloat(cos(t * 2)), y: 92)
            let lifted = CGPoint(x: x - 58, y: 62)
            let tip = CGPoint(x: stir.x + (lifted.x - stir.x) * CGFloat(taste),
                              y: stir.y + (lifted.y - stir.y) * CGFloat(taste))
            let paw = CGPoint(x: tip.x - 34 + 18 * CGFloat(taste), y: tip.y - 28 + 40 * CGFloat(taste))
            Kit.utensil(c, from: tip, to: paw, color: Kit.wood)
            c.fill(Path(ellipseIn: CGRect(x: tip.x - 7, y: tip.y - 4, width: 14, height: 8)), with: .color(Kit.wood))
            if taste > 0.6 {
                drawSteam(c, origin: CGPoint(x: tip.x, y: tip.y - 8), spread: 10, t: t, heat: 1, count: 2, rise: 22)
            }
            return paw
        }
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
        // One chop per beat: the knife rises and falls smoothly, gliding along
        // to the next cut while it's up. After eight slices it lifts, slides
        // back and the pile clears, then it starts again.
        let beat = 0.55 / max(1, heat)
        let beats = t / beat
        let index = Int(beats.rounded(.down)) % 9
        let phase = Self.fraction(beats)
        let ease = phase * phase * (3 - 2 * phase)
        let isReset = index == 8
        let slices = isReset ? 8 : index
        let base = x - 10
        let cut = base + CGFloat(slices) * 5
        let knifeX = isReset ? base + CGFloat(8 * (1 - ease)) * 5 : base + (CGFloat(index) + CGFloat(ease)) * 5
        let pileFade = isReset ? 1 - ease : 1
        let (skinColor, flesh): (Color, Color) = switch produce {
        case .carrot: (Kit.carrot, Kit.egg)
        case .onion: (Kit.onionSkin, Kit.onion)
        case .tomato: (Kit.tomato, Kit.tomatoFlesh)
        case .greens: (Kit.greens, Kit.leafLight)
        case .potato: (Kit.potatoSkin, Kit.potato)
        }
        for i in 0..<slices {
            let sx = x - 58 + CGFloat(i) * 6
            c.fill(Path(ellipseIn: CGRect(x: sx, y: 130 + CGFloat(i % 2), width: 9, height: 9)),
                   with: .color(skinColor.opacity(pileFade)))
            c.fill(Kit.circle(CGPoint(x: sx + 4.5, y: 134.5 + CGFloat(i % 2)), 2), with: .color(flesh.opacity(pileFade)))
        }
        if produce == .onion || produce == .tomato || produce == .potato {
            // A round thing, cut down to a shrinking dome.
            let width = x + 44 - cut
            c.fill(Path(roundedRect: CGRect(x: cut, y: 118, width: width, height: 20), cornerRadius: 10),
                   with: .color(skinColor))
            c.fill(Path(roundedRect: CGRect(x: cut, y: 121, width: 4, height: 14), cornerRadius: 2), with: .color(flesh))
        } else {
            c.fill(Path(roundedRect: CGRect(x: cut, y: 126, width: x + 44 - cut, height: 12), cornerRadius: 6),
                   with: .color(skinColor))
            for (i, angle) in [-30.0, 0, 30].enumerated() {
                var leaf = c
                leaf.translateBy(x: x + 46, y: 132)
                leaf.rotate(by: .degrees(angle))
                leaf.fill(Path(ellipseIn: CGRect(x: 0, y: -3, width: 14 + CGFloat(i % 2) * 3, height: 6)), with: .color(Kit.greens))
            }
        }
        if produce == .onion {
            // Onion tears, flying off his goggles.
            for i in 0..<2 {
                let phase = Self.fraction(t * 0.8 + Double(i) * 0.5)
                c.fill(Kit.circle(CGPoint(x: 150 + CGFloat(phase) * 14, y: 70 + CGFloat(phase) * 20), 2.2),
                       with: .color(Kit.water.opacity(1 - phase)))
            }
        }
        // Up and down in one smooth wave, lifting higher for the slide back.
        let lift = CGFloat((1 - cos(2 * .pi * phase)) / 2) * (isReset ? 18 : 11)
        let k = knifeX
        var blade = Path()
        blade.move(to: CGPoint(x: k - 26, y: 116 - lift))
        blade.addLine(to: CGPoint(x: k + 3, y: 116 - lift))
        blade.addLine(to: CGPoint(x: k + 3, y: 137 - lift))
        blade.addQuadCurve(to: CGPoint(x: k - 26, y: 128 - lift), control: CGPoint(x: k - 16, y: 137 - lift))
        blade.closeSubpath()
        c.fill(blade, with: .color(Kit.chrome))
        c.fill(Path(roundedRect: CGRect(x: k - 50, y: 116 - lift, width: 26, height: 8), cornerRadius: 4),
               with: .color(Kit.dark))
        return CGPoint(x: k - 46, y: 120 - lift)
    }

    private func drawMix(_ c: GraphicsContext, x: CGFloat, t: Double, heat: Double) -> CGPoint {
        var bowl = Path()
        bowl.move(to: CGPoint(x: x - 48, y: 114))
        bowl.addQuadCurve(to: CGPoint(x: x + 48, y: 114), control: CGPoint(x: x, y: 172))
        bowl.closeSubpath()
        c.fill(bowl, with: .color(bowlColor))
        c.stroke(bowl, with: .color(Kit.applianceEdge), lineWidth: 2)
        c.fill(Path(ellipseIn: CGRect(x: x - 48, y: 108, width: 96, height: 13)), with: .color(Kit.applianceEdge))
        c.fill(Path(ellipseIn: CGRect(x: x - 42, y: 110, width: 84, height: 9)), with: .color(Kit.oats))
        // Bits of this and that, turned over with a wooden spoon.
        let bits: [(CGFloat, Color)] = [(-24, Kit.greens), (-8, Kit.carrot), (10, Kit.tomato), (24, Kit.egg)]
        let toss = Self.pulse(t, every: 3.2, lasting: 0.6)
        for (i, bit) in bits.enumerated() {
            let lift = CGFloat(toss * (10 + Double(i % 2) * 6))
            c.fill(Path(ellipseIn: CGRect(x: x + bit.0 - 5, y: 110 - lift, width: 10, height: 6)), with: .color(bit.1))
        }
        let angle = t * 2.4 * heat
        let tip = CGPoint(x: x + 20 * CGFloat(cos(angle)), y: 114 + 3 * CGFloat(sin(angle)))
        let paw = CGPoint(x: tip.x - 38, y: tip.y - 34)
        Kit.utensil(c, from: tip, to: paw, color: Kit.wood)
        c.fill(Path(ellipseIn: CGRect(x: tip.x - 6, y: tip.y - 3, width: 12, height: 7)), with: .color(Kit.wood))
        return paw
    }

    /// A mixing bowl, shared by the whisk, crack and mash scenes.
    private func drawBowl(_ c: GraphicsContext, x: CGFloat, filling: Color) {
        var bowl = Path()
        bowl.move(to: CGPoint(x: x - 48, y: 114))
        bowl.addQuadCurve(to: CGPoint(x: x + 48, y: 114), control: CGPoint(x: x, y: 172))
        bowl.closeSubpath()
        c.fill(bowl, with: .color(bowlColor))
        c.stroke(bowl, with: .color(Kit.applianceEdge), lineWidth: 2)
        c.fill(Path(ellipseIn: CGRect(x: x - 48, y: 108, width: 96, height: 13)), with: .color(Kit.applianceEdge))
        c.fill(Path(ellipseIn: CGRect(x: x - 42, y: 110, width: 84, height: 9)), with: .color(filling))
    }

    private func drawWhisk(_ c: GraphicsContext, x: CGFloat, t: Double, heat: Double) -> CGPoint {
        drawBowl(c, x: x, filling: Kit.batter)
        // Froth building up on top.
        for i in 0..<6 {
            let bx = x - 30 + CGFloat(i) * 12
            let r = CGFloat(2 + abs(sin(t * 3 + Double(i))) * 2)
            c.stroke(Kit.circle(CGPoint(x: bx, y: 112), r), with: .color(.white.opacity(0.8)), lineWidth: 1.2)
        }
        // A whisk going round, fast, flicking the odd drop.
        let angle = t * 4.5 * heat
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

    private func drawCrack(_ c: GraphicsContext, x: CGFloat, t: Double) -> CGPoint {
        drawBowl(c, x: x, filling: Kit.egg)
        c.fill(Kit.circle(CGPoint(x: x + 8, y: 114), 6), with: .color(Kit.yolk))
        // Tap, tap, crack: the egg comes down on the rim and splits open.
        let cycle = Self.fraction(t / 2.6)
        let egg = CGPoint(x: x - 18, y: 104)
        if cycle < 0.55 {
            let tap = CGFloat(abs(sin(cycle / 0.55 * .pi * 2))) * 10
            let center = CGPoint(x: egg.x, y: egg.y - 18 - tap)
            let shell = Path(ellipseIn: CGRect(x: center.x - 10, y: center.y - 13, width: 20, height: 26))
            c.fill(shell, with: .color(Kit.shell))
            c.stroke(shell, with: .color(Kit.crust), lineWidth: 1.5)
            return CGPoint(x: center.x - 14, y: center.y + 4)
        }
        // Open: two halves tip apart and the yolk drops.
        let open = CGFloat(min(1, (cycle - 0.55) / 0.2))
        for side in [-1.0, 1.0] {
            var half = c
            half.translateBy(x: egg.x + CGFloat(side) * 6 * open, y: egg.y - 18)
            half.rotate(by: .degrees(side * 40 * open))
            let piece = Path(roundedRect: CGRect(x: -10, y: -13, width: 20, height: 13), cornerRadius: 7)
            half.fill(piece, with: .color(Kit.shell))
            half.stroke(piece, with: .color(Kit.crust), lineWidth: 1.5)
        }
        let drop = CGFloat(min(1, (cycle - 0.6) / 0.25))
        if drop > 0 {
            c.fill(Kit.circle(CGPoint(x: egg.x + 8 * drop, y: egg.y - 12 + 24 * drop), 5), with: .color(Kit.yolk))
        }
        return CGPoint(x: egg.x - 18, y: egg.y - 14)
    }

    private func drawSeason(_ c: GraphicsContext, x: CGFloat, t: Double) -> CGPoint {
        // A pan of food on the counter, and a salt shaker standing by.
        c.fill(Path(roundedRect: CGRect(x: x - 46, y: 128, width: 82, height: 16), cornerRadius: 8), with: .color(metal))
        c.fill(Path(ellipseIn: CGRect(x: x - 48, y: 122, width: 86, height: 12)), with: .color(Kit.rim))
        c.fill(Path(ellipseIn: CGRect(x: x - 42, y: 124, width: 74, height: 8)), with: .color(Kit.toast))
        let shaker = CGRect(x: x + 46, y: 112, width: 18, height: 34)
        c.fill(Path(roundedRect: shaker, cornerRadius: 6), with: .color(Kit.plate))
        c.fill(Path(roundedRect: CGRect(x: shaker.minX, y: shaker.minY, width: 18, height: 8), cornerRadius: 4), with: .color(Kit.chrome))
        // A pepper grinder, twisting, with specks falling.
        let twist = CGFloat(sin(t * 5)) * 4
        let grinder = CGRect(x: x - 10, y: 62, width: 16, height: 40)
        c.fill(Path(roundedRect: grinder, cornerRadius: 6), with: .color(Kit.wood))
        c.fill(Path(roundedRect: CGRect(x: grinder.minX - 2 + twist / 2, y: grinder.minY - 8, width: 20, height: 10),
                    cornerRadius: 5), with: .color(Kit.crust))
        c.fill(Kit.circle(CGPoint(x: grinder.midX + twist / 2, y: grinder.minY - 11), 3.5), with: .color(Kit.dark))
        for i in 0..<8 {
            let phase = Self.fraction(t * 1.2 + Double(i) * 0.125)
            let sx = grinder.midX - 6 + CGFloat(Self.fraction(Double(i) * 0.618)) * 12
            c.fill(Kit.circle(CGPoint(x: sx, y: grinder.maxY + 4 + CGFloat(phase) * 22), 1.2),
                   with: .color(Kit.dark.opacity(1 - phase * 0.6)))
        }
        return CGPoint(x: grinder.minX - 6, y: grinder.midY)
    }

    private func drawSpread(_ c: GraphicsContext, x: CGFloat, t: Double) -> CGPoint {
        c.fill(Path(roundedRect: CGRect(x: x - 62, y: 138, width: 118, height: 10), cornerRadius: 5), with: .color(Kit.board))
        c.fill(Path(roundedRect: CGRect(x: x - 62, y: 145, width: 118, height: 5), cornerRadius: 2.5), with: .color(Kit.boardEdge))
        // A slice of toast, getting buttered from one side to the other.
        let slice = CGRect(x: x - 40, y: 118, width: 58, height: 22)
        c.fill(Path(roundedRect: slice, cornerRadius: 7), with: .color(Kit.crust))
        c.fill(Path(roundedRect: slice.insetBy(dx: 3, dy: 3), cornerRadius: 5), with: .color(Kit.toast))
        let covered = CGFloat(Self.fraction(t / 4))
        c.fill(Path(roundedRect: CGRect(x: slice.minX + 4, y: slice.minY + 4, width: (slice.width - 8) * covered, height: 7),
                    cornerRadius: 3.5), with: .color(Kit.butter))
        // The butter dish.
        c.fill(Path(roundedRect: CGRect(x: x + 26, y: 132, width: 36, height: 8), cornerRadius: 3), with: .color(Kit.plate))
        c.fill(Path(roundedRect: CGRect(x: x + 32, y: 122, width: 24, height: 11), cornerRadius: 3), with: .color(Kit.butter))
        // The knife sweeps across with the butter.
        let sweep = slice.minX + 8 + (slice.width - 16) * covered + CGFloat(sin(t * 8)) * 3
        let blade = CGRect(x: sweep - 10, y: slice.minY - 2, width: 22, height: 5)
        c.fill(Path(roundedRect: blade, cornerRadius: 2.5), with: .color(Kit.chrome))
        let paw = CGPoint(x: blade.minX - 20, y: blade.minY - 14)
        Kit.utensil(c, from: CGPoint(x: blade.minX, y: blade.midY), to: paw, color: Kit.dark)
        return paw
    }

    private func drawMash(_ c: GraphicsContext, x: CGFloat, t: Double, heat: Double) -> CGPoint {
        drawBowl(c, x: x, filling: Kit.batter)
        // Lumpy potato on top.
        for i in 0..<5 {
            c.fill(Kit.circle(CGPoint(x: x - 28 + CGFloat(i) * 14, y: 111 - CGFloat(i % 2) * 2), 7), with: .color(Kit.potato))
        }
        // The masher pumps up and down.
        let press = CGFloat(abs(sin(t * 3.4 * max(1, heat))))
        let head = CGPoint(x: x - 2, y: 104 - 18 * press)
        var grid = Path()
        grid.move(to: CGPoint(x: head.x - 14, y: head.y))
        for i in 1...4 {
            grid.addLine(to: CGPoint(x: head.x - 14 + CGFloat(i) * 7, y: head.y + (i % 2 == 0 ? 0 : 5)))
        }
        c.stroke(grid, with: .color(Kit.chrome), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        Kit.utensil(c, from: head, to: CGPoint(x: head.x, y: head.y - 24), color: Kit.chrome)
        c.fill(Path(roundedRect: CGRect(x: head.x - 5, y: head.y - 34, width: 10, height: 16), cornerRadius: 4), with: .color(Kit.wood))
        if press < 0.15 {
            for i in 0..<3 {
                Kit.sparkle(c, at: CGPoint(x: x - 20 + CGFloat(i) * 20, y: 100), size: 3, color: Kit.potato)
            }
        }
        return CGPoint(x: head.x - 6, y: head.y - 28)
    }

    private func drawDrain(_ c: GraphicsContext, x: CGFloat, t: Double, heat: Double) -> CGPoint {
        // The sink, set into the counter, with a tap on the far side.
        c.fill(Path(roundedRect: CGRect(x: x - 60, y: 142, width: 120, height: 8), cornerRadius: 4), with: .color(Kit.sink))
        var tap = Path()
        tap.move(to: CGPoint(x: x + 62, y: 146))
        tap.addLine(to: CGPoint(x: x + 62, y: 104))
        tap.addQuadCurve(to: CGPoint(x: x + 44, y: 104), control: CGPoint(x: x + 62, y: 92))
        tap.addLine(to: CGPoint(x: x + 44, y: 110))
        c.stroke(tap, with: .color(Kit.chrome), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
        // A colander catching everything.
        var colander = Path()
        colander.move(to: CGPoint(x: x - 34, y: 116))
        colander.addQuadCurve(to: CGPoint(x: x + 34, y: 116), control: CGPoint(x: x, y: 158))
        colander.closeSubpath()
        c.fill(colander, with: .color(Kit.chrome))
        for i in 0..<5 {
            c.fill(Kit.circle(CGPoint(x: x - 18 + CGFloat(i) * 9, y: 126 + CGFloat(i % 2) * 4), 1.6), with: .color(Kit.dark.opacity(0.5)))
        }
        c.fill(Path(ellipseIn: CGRect(x: x - 34, y: 111, width: 68, height: 10)), with: .color(Kit.rim))
        c.fill(Path(ellipseIn: CGRect(x: x - 28, y: 112, width: 56, height: 7)), with: .color(Kit.pasta))
        // The pot, on its side and tipped toward the colander: the open top
        // faces right, its handle is on the left, in Nutmeg's paw.
        var pot = c
        pot.translateBy(x: x - 44, y: 82)
        pot.rotate(by: .degrees(28 + sin(t * 1.5) * 3))
        pot.fill(Path(roundedRect: CGRect(x: -44, y: -3, width: 16, height: 7), cornerRadius: 3.5), with: .color(metal))
        pot.fill(Path(roundedRect: CGRect(x: -30, y: -20, width: 52, height: 40), cornerRadius: 9), with: .color(metal))
        pot.fill(Path(roundedRect: CGRect(x: -24, y: -14, width: 6, height: 28), cornerRadius: 3), with: .color(.white.opacity(0.18)))
        pot.fill(Path(ellipseIn: CGRect(x: 16, y: -22, width: 13, height: 44)), with: .color(Kit.rim))
        pot.fill(Path(ellipseIn: CGRect(x: 19, y: -17, width: 8, height: 34)), with: .color(Kit.water))
        // Water pouring from the pot's lip into the colander, and steam off it.
        let lip = CGPoint(x: x - 20, y: 100)
        for i in 0..<6 {
            let phase = Self.fraction(t * 1.8 + Double(i) / 6)
            let p = CGPoint(x: lip.x + CGFloat(phase) * 10 + CGFloat(sin(t * 6 + Double(i))) * 1.5,
                            y: lip.y + CGFloat(phase) * 14)
            c.fill(Kit.circle(p, 3), with: .color(Kit.water))
        }
        drawSteam(c, origin: CGPoint(x: x, y: 100), spread: 40, t: t, heat: heat, count: 3, rise: 56)
        return CGPoint(x: x - 82, y: 64)
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
    static let onion = hex(0xF6ECF3)
    static let onionSkin = hex(0xB37AAE)
    static let tomato = hex(0xE0503C)
    static let tomatoFlesh = hex(0xF6A08E)
    static let leafLight = hex(0xB9D69A)
    static let yolk = hex(0xF7B733)
    static let shell = hex(0xE6C398)
    static let butter = hex(0xFBE38E)
    static let potato = hex(0xF4E2B0)
    static let pasta = hex(0xF3D48A)
    static let mitt = hex(0xD64A4A)
    static let potatoSkin = hex(0xB5835A)
    static let sink = hex(0xAFB6BF)
    static let blueEnamel = hex(0x4F7FB0)
    static let sageBowl = hex(0xDCE8CF)

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
                KitchenStage(scene: scene, variant: scene.rawValue.count % CookScene.variants, emoji: "🍝")
            }
        }
        .padding()
    }
    .background(Theme.Palette.background)
}

#if DEBUG
/// Kitchen scenes side by side, for checking the drawings (debug builds only).
struct KitchenSceneGallery: View {
    let scenes: [CookScene]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(scenes, id: \.self) { scene in
                    ForEach(0..<CookScene.variants, id: \.self) { variant in
                        KitchenStage(scene: scene, variant: variant,
                                     produce: variant == 1 ? .onion : (variant == 2 ? .tomato : .carrot),
                                     emoji: "🍝")
                            .frame(height: 170)
                    }
                }
            }
            .padding(.horizontal, 10)
        }
        .background(Theme.Palette.background.ignoresSafeArea())
    }
}
#endif
