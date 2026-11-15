import SwiftUI

enum Theme {
    static let ink = Color(hex: 0x0B0B0C)
    static let panel = Color(hex: 0x16171A)
    static let panel2 = Color(hex: 0x202226)
    static let line = Color(hex: 0x2E3036)
    static let acid = Color(hex: 0xE8FF3A)
    static let paper = Color(hex: 0xF4F4F0)
    static let dim = Color(hex: 0x9A9CA3)
    static let hot = Color(hex: 0xFF2E88)
    static let cyan = Color(hex: 0x2EE6FF)
}

extension Font {
    /// Tall, compressed, heavy display type (street-poster look).
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.compressed)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Shapes

/// Parallelogram – the signature slanted button/label.
struct Slant: Shape {
    var cut: CGFloat = 10
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + cut, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - cut, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Panel with two clipped corners (top-left / bottom-right).
struct CutPanel: Shape {
    var cut: CGFloat = 16
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + cut, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cut))
        p.addLine(to: CGPoint(x: r.maxX - cut, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + cut))
        p.closeSubpath()
        return p
    }
}

// MARK: - Backgrounds

struct Halftone: View {
    var color: Color = Theme.acid
    var spacing: CGFloat = 10
    var radius: CGFloat = 1.4
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            var row = 0
            while y < size.height + spacing {
                var x: CGFloat = row.isMultiple(of: 2) ? 0 : spacing / 2
                while x < size.width + spacing {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(color))
                    x += spacing
                }
                y += spacing
                row += 1
            }
        }
        .allowsHitTesting(false)
    }
}

struct Scanlines: View {
    var body: some View {
        Canvas { ctx, size in
            var y: CGFloat = 0
            while y < size.height {
                ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.white.opacity(0.035)))
                y += 4
            }
        }
        .allowsHitTesting(false)
    }
}

struct HazardStripe: View {
    var color: Color = Theme.acid
    var band: CGFloat = 10
    var body: some View {
        Canvas { ctx, size in
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height + band, y: 0))
                p.addLine(to: CGPoint(x: x + band, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(color))
                x += band * 2
            }
        }
        .allowsHitTesting(false)
    }
}

/// TV static noise, used as a channel-switch transition.
struct StaticNoise: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { _ in
            Canvas { ctx, size in
                let cell: CGFloat = 4
                let cols = Int(size.width / cell) + 1
                let rows = Int(size.height / cell) + 1
                for _ in 0..<(cols * rows / 3) {
                    let x = CGFloat(Int.random(in: 0..<cols)) * cell
                    let y = CGFloat(Int.random(in: 0..<rows)) * cell
                    ctx.fill(Path(CGRect(x: x, y: y, width: cell, height: cell)),
                             with: .color(.white.opacity(Double.random(in: 0.15...0.9))))
                }
                for _ in 0..<4 {
                    let y = CGFloat.random(in: 0...size.height)
                    ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: CGFloat.random(in: 2...10))),
                             with: .color([Theme.hot, Theme.cyan, Theme.acid].randomElement()!.opacity(0.6)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Components

struct SlantButtonStyle: ButtonStyle {
    var fill: Color = Theme.acid
    var text: Color = Theme.ink
    var outline = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(19))
            .tracking(1)
            .foregroundStyle(outline ? fill : text)
            .padding(.horizontal, 18)
            .frame(minHeight: 46)
            .background {
                if outline {
                    Slant().stroke(fill, lineWidth: 2)
                } else {
                    Slant().fill(fill)
                        .background(Slant().fill(Color.black).offset(x: 4, y: 4))
                }
            }
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? 3 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct Tag: View {
    var text: String
    var fill: Color = Theme.acid
    var fg: Color = Theme.ink
    var body: some View {
        Text(text)
            .font(.mono(10))
            .tracking(1.5)
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Slant(cut: 6).fill(fill))
    }
}

struct BlinkDot: View {
    var color: Color = Theme.hot
    @State private var on = true
    var body: some View {
        Circle().fill(color).frame(width: 8, height: 8)
            .opacity(on ? 1 : 0.2)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) { on.toggle() }
            }
    }
}

struct Toast: View {
    var text: String
    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.ink).frame(width: 6, height: 18)
            Text(text).font(.mono(13)).foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(Slant(cut: 12).fill(Theme.acid))
        .shadow(color: .black.opacity(0.5), radius: 0, x: 5, y: 5)
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func ok() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func fail() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
