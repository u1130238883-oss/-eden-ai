import SwiftUI

// 街頭漫畫風：黑底、螢光黃綠、撞色粉、斜切形狀、網點、警示膠帶。

enum Theme {
    static let bg = Color(hex: 0x0A0A0C)
    static let panel = Color(hex: 0x15151A)
    static let panel2 = Color(hex: 0x202028)
    static let neon = Color(hex: 0xD4FF1F)
    static let pink = Color(hex: 0xFF2E7E)
    static let cyan = Color(hex: 0x2EE6FF)
    static let muted = Color(hex: 0x8B8B96)
    static let danger = Color(hex: 0xFF4D4D)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

extension Font {
    /// 粗黑斜體窄字，用於標題和按鈕。
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.condensed).italic()
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - 形狀

/// 平行四邊形。
struct Slant: Shape {
    var cut: CGFloat = 12

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

/// 右上角和左下角切角的矩形。
struct CutCorner: Shape {
    var cut: CGFloat = 16

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - cut, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + cut))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + cut, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - cut))
        p.closeSubpath()
        return p
    }
}

// MARK: - 裝飾

/// 漫畫網點，從右上角向左下漸隱。
struct Halftone: View {
    var color: Color = Theme.neon
    var spacing: CGFloat = 11

    var body: some View {
        Canvas { ctx, size in
            let span = size.width + size.height
            for y in stride(from: 0, through: size.height, by: spacing) {
                for x in stride(from: 0, through: size.width, by: spacing) {
                    let t = ((size.width - x) + y) / span
                    let r = spacing * 0.42 * (1 - t * 1.4)
                    guard r > 0.4 else { continue }
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(color))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 黃黑警示膠帶，中間可以帶文字。
struct CautionTape: View {
    var text: String = ""
    var height: CGFloat = 22

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.neon))
                let w: CGFloat = 12
                for x in stride(from: -size.height, through: size.width + size.height, by: w * 2) {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: size.height))
                    p.addLine(to: CGPoint(x: x + size.height, y: 0))
                    p.addLine(to: CGPoint(x: x + size.height + w, y: 0))
                    p.addLine(to: CGPoint(x: x + w, y: size.height))
                    ctx.fill(p, with: .color(.black))
                }
            }
            if !text.isEmpty {
                Text(text)
                    .font(.mono(11, .heavy))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.neon)
            }
        }
        .frame(height: height)
        .clipped()
    }
}

/// 小標籤，例如「已簽名」。
struct Tag: View {
    var text: String
    var color: Color = Theme.neon
    var filled = true

    var body: some View {
        Text(text)
            .font(.mono(10, .heavy))
            .foregroundColor(filled ? .black : color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Slant(cut: 4).fill(filled ? color : .clear))
            .overlay(Slant(cut: 4).stroke(color, lineWidth: filled ? 0 : 1))
    }
}

/// 頁面大標題：代號 + 斜體大字 + 撞色下劃線。
struct ScreenHeader: View {
    var code: String
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(code)
                    .font(.mono(11, .heavy))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.neon)
                Text("// \(subtitle)")
                    .font(.mono(11))
                    .foregroundColor(Theme.muted)
            }
            Text(title)
                .font(.display(46))
                .foregroundColor(.white)
            Rectangle()
                .fill(Theme.pink)
                .frame(width: 64, height: 5)
                .rotationEffect(.degrees(-4))
        }
        .padding(.top, 8)
    }
}

/// 分區小標題。
struct SectionLabel: View {
    var text: String

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(Theme.neon).frame(width: 10, height: 3)
            Text(text)
                .font(.mono(12, .heavy))
                .foregroundColor(Theme.muted)
        }
    }
}

// MARK: - 按鈕和卡片

struct NeonButtonStyle: ButtonStyle {
    var color: Color = Theme.neon
    var shadow: Color = Theme.pink
    var foreground: Color = .black

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(21))
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Slant(cut: 14).fill(color))
            .background(Slant(cut: 14).fill(shadow).offset(x: 5, y: 5))
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? 3 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var color: Color = Theme.neon

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(18))
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Slant(cut: 12).fill(color.opacity(configuration.isPressed ? 0.18 : 0.06)))
            .overlay(Slant(cut: 12).stroke(color, lineWidth: 1.5))
    }
}

struct Panel: ViewModifier {
    var accent: Color = Theme.neon

    func body(content: Content) -> some View {
        content
            .padding(14)
            .padding(.leading, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CutCorner(cut: 16).fill(Theme.panel))
            .overlay(CutCorner(cut: 16).stroke(Color.white.opacity(0.07), lineWidth: 1))
            .overlay(alignment: .leading) {
                Rectangle().fill(accent).frame(width: 4).padding(.vertical, 12)
            }
    }
}

extension View {
    func panel(accent: Color = Theme.neon) -> some View {
        modifier(Panel(accent: accent))
    }
}

/// 深色輸入框。
struct NeoField: View {
    var label: String
    var placeholder: String
    @Binding var text: String
    var secure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.mono(11, .heavy)).foregroundColor(Theme.muted)
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(12)
            .background(Slant(cut: 8).fill(Theme.panel2))
        }
    }
}

/// 處理中時的掃描條動畫。
struct ScanBar: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Slant(cut: 8).fill(Theme.panel2)
                Slant(cut: 8)
                    .fill(LinearGradient(colors: [Theme.neon.opacity(0), Theme.neon, Theme.pink],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * 0.35)
                    .offset(x: (geo.size.width * 1.35) * phase - geo.size.width * 0.35)
            }
            .clipShape(Slant(cut: 8))
        }
        .frame(height: 12)
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { phase = 1 }
        }
    }
}
