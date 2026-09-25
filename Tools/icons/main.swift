import SwiftUI
import AppKit

@MainActor
func render<V: View>(_ view: V, width: CGFloat, height: CGFloat, to path: String) {
    let renderer = ImageRenderer(content: view.frame(width: width, height: height))
    renderer.scale = 1
    guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { fatalError("render failed: \(path)") }
    try! png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

func hex(_ v: UInt32) -> Color {
    Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
}

/// The whole icon: a plain background and Nutmeg, sized the way the approved
/// icon has him (the art's 430 x 430 core scaled to 840 with a 92 margin).
struct IconArt: View {
    let skin: NutmegSkin
    let background: Color
    var flakes = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            if flakes {
                ForEach(0..<14, id: \.self) { i in
                    let x = (Double(i) * 0.618).truncatingRemainder(dividingBy: 1) * 960 + 30
                    let y = (Double(i) * 0.377).truncatingRemainder(dividingBy: 1) * 960 + 30
                    Circle().fill(.white.opacity(0.85)).frame(width: 14 + CGFloat(i % 3) * 8)
                        .position(x: x, y: y)
                }
            }
            NutmegView(pose: .noHands, skin: skin, showsWeather: false)
                .frame(width: 680 * 1.953, height: 530 * 1.953)
                .offset(x: 92 - 125 * 1.953, y: 92 - 75 * 1.953)
        }
        .frame(width: 1024, height: 1024, alignment: .topLeading)
        .clipped()
    }
}

/// Every look side by side, on the cream background, for a quick check.
struct Sheet: View {
    var body: some View {
        HStack(spacing: 20) {
            ForEach([NutmegSkin.amber, .coral, .snow, .harvest], id: \.self) { skin in
                NutmegView(skin: skin, showsWeather: false).frame(width: 340, height: 265)
            }
        }
        .padding(20)
        .background(hex(0xFBF3E6))
    }
}

MainActor.assumeIsolated {
    let out = CommandLine.arguments[1]
    render(Sheet(), width: 1440, height: 305, to: "\(out)/looks.png")
    render(IconArt(skin: .amber, background: hex(0x3B2A1A)), width: 1024, height: 1024, to: "\(out)/icon-default.png")
    render(IconArt(skin: .amber, background: hex(0x1D140C)), width: 1024, height: 1024, to: "\(out)/icon-dark.png")
    render(IconArt(skin: .mono, background: hex(0xD6D6D6)), width: 1024, height: 1024, to: "\(out)/icon-tinted.png")
    render(IconArt(skin: .coral, background: hex(0x3B2A1A)), width: 1024, height: 1024, to: "\(out)/icon-coral.png")
    render(IconArt(skin: .snow, background: hex(0x1F3A5F), flakes: true), width: 1024, height: 1024, to: "\(out)/icon-snow.png")
    render(IconArt(skin: .harvest, background: hex(0x5A2E12)), width: 1024, height: 1024, to: "\(out)/icon-harvest.png")
}
