import SwiftUI

/// 街頭潮流 × 霓虹 × 漫畫網點 的視覺語言。
enum Theme {
    static let ink = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let panel = Color(red: 0.09, green: 0.09, blue: 0.11)
    static let panelHi = Color(red: 0.14, green: 0.14, blue: 0.17)
    // 與 Hollow 同一套配色：螢光黃綠、橘、青
    static let hazard = Color(red: 0.83, green: 1.0, blue: 0.12)
    static let orange = Color(red: 1.0, green: 0.42, blue: 0.08)
    static let neonPink = Color(red: 1.0, green: 0.24, blue: 0.5)
    static let signal = Color(red: 0.2, green: 0.88, blue: 1.0)
    static let paper = Color(red: 0.95, green: 0.94, blue: 0.9)
    static let dim = Color.white.opacity(0.45)

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default).italic()
    }

    static func hud(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

/// 斜切平行四邊形（招牌式對話框、按鈕）。
struct Slanted: Shape {
    var skew: CGFloat = 10
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + skew, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - skew, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// 缺角面板：右下角被切掉一刀。
struct NotchedPanel: Shape {
    var cut: CGFloat = 14
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cut))
        p.addLine(to: CGPoint(x: r.maxX - cut, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// 漫畫網點背景 + 斜向光帶。
struct HalftoneBackground: View {
    var body: some View {
        ZStack {
            Theme.ink
            Canvas { ctx, size in
                let step: CGFloat = 14
                var y: CGFloat = 0
                var row = 0
                while y < size.height + step {
                    var x: CGFloat = row % 2 == 0 ? 0 : step / 2
                    while x < size.width + step {
                        // 越靠右下，網點越大
                        let t = min(1, (x / size.width + y / size.height) / 2)
                        let d = 1.2 + 2.6 * t
                        ctx.fill(Path(ellipseIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)),
                                 with: .color(.white.opacity(0.05)))
                        x += step
                    }
                    y += step * 0.866
                    row += 1
                }
            }
            LinearGradient(colors: [Theme.neonPink.opacity(0.16), .clear, Theme.signal.opacity(0.1)],
                           startPoint: .topTrailing, endPoint: .bottomLeading)
        }
        .ignoresSafeArea()
    }
}

/// 黃黑警示條。
struct HazardStripes: View {
    var height: CGFloat = 8
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.hazard))
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height * 1.8, y: 0))
                p.addLine(to: CGPoint(x: x + size.height * 0.8, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(Theme.ink))
                x += size.height * 2.2
            }
        }
        .frame(height: height)
    }
}

/// 貼紙式小標籤。
struct TagLabel: View {
    let text: String
    var fg: Color = Theme.ink
    var bg: Color = Theme.hazard
    var body: some View {
        Text(text)
            .font(Theme.hud(10))
            .foregroundColor(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Slanted(skew: 5).fill(bg))
    }
}

/// 故障（glitch）文字：RGB 錯位 + 隨機抖動。
struct GlitchText: View {
    let text: String
    var size: CGFloat = 34
    @State private var jitter: CGFloat = 0

    var body: some View {
        ZStack {
            Text(text).foregroundColor(Theme.neonPink).offset(x: -2 - jitter, y: 0)
            Text(text).foregroundColor(Theme.signal).offset(x: 2 + jitter, y: 0)
            Text(text).foregroundColor(Theme.paper)
        }
        .font(Theme.display(size))
        .onReceive(Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()) { _ in
            jitter = Double.random(in: 0...1) < 0.2 ? CGFloat.random(in: -3...3) : 0
        }
    }
}
