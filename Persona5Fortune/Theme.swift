import SwiftUI
import UIKit

// MARK: - 絕區零風格：黑底、螢光黃綠、警示條紋、電視螢幕

enum Z {
    static let bg = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let panel = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let panel2 = Color(red: 0.16, green: 0.16, blue: 0.19)
    static let lime = Color(red: 0.83, green: 1.0, blue: 0.12)
    static let orange = Color(red: 1.0, green: 0.42, blue: 0.08)
    static let cyan = Color(red: 0.2, green: 0.85, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.3, blue: 0.55)
    static let text = Color.white
    static let dim = Color.white.opacity(0.6)

    static func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func title(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func body(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func mono(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .heavy, design: .monospaced) }
}

// MARK: - Shapes

/// 黃黑警示條紋
struct HazardStripes: View {
    var color: Color = Z.lime
    var stripe: CGFloat = 10

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            var x: CGFloat = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                p.addLine(to: CGPoint(x: x + size.height + stripe, y: 0))
                p.addLine(to: CGPoint(x: x + stripe, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(color))
                x += stripe * 2
            }
        }
    }
}

/// 切角矩形（右上、左下切角）
struct CutCorner: Shape {
    var cut: CGFloat = 14

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

// MARK: - 背景

struct ZBackground: View {
    var body: some View {
        ZStack {
            Z.bg
            Canvas { ctx, size in
                // 點陣
                let step: CGFloat = 18
                var y: CGFloat = 0
                while y < size.height {
                    var x: CGFloat = 0
                    while x < size.width {
                        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.6, height: 1.6)),
                                 with: .color(.white.opacity(0.07)))
                        x += step
                    }
                    y += step
                }
                // 斜向色塊
                var p = Path()
                p.move(to: CGPoint(x: size.width * 0.55, y: 0))
                p.addLine(to: CGPoint(x: size.width, y: 0))
                p.addLine(to: CGPoint(x: size.width, y: size.height * 0.22))
                p.closeSubpath()
                ctx.fill(p, with: .color(Z.lime.opacity(0.06)))
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - 卡片

/// 圓角面板 + 偏移色影，左上角可帶「膠帶」標籤。
struct ZCard<Content: View>: View {
    var tag: String? = nil
    var tagColor: Color = Z.lime
    var accent: Color = Z.lime
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let tag {
                Text(tag)
                    .font(Z.title(13))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(tagColor)
                    .clipShape(Capsule())
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(accent.opacity(0.9)).offset(x: 4, y: 5)
                RoundedRectangle(cornerRadius: 20).fill(Z.panel)
                RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 3)
            }
        )
    }
}

/// 電視螢幕框（掃描線）
struct TVScreen<Content: View>: View {
    var glow: Color = Z.lime
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 26).fill(Color(red: 0.07, green: 0.09, blue: 0.08))
                    Canvas { ctx, size in
                        var y: CGFloat = 0
                        while y < size.height {
                            ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                                     with: .color(.white.opacity(0.05)))
                            y += 4
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    RadialGradient(colors: [glow.opacity(0.22), .clear], center: .center, startRadius: 10, endRadius: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.black, lineWidth: 6))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(glow.opacity(0.8), lineWidth: 2).padding(3))
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 32).fill(Z.panel2))
            .overlay(RoundedRectangle(cornerRadius: 32).stroke(Color.black, lineWidth: 3))
    }
}

// MARK: - 按鈕

struct ZButtonStyle: ButtonStyle {
    var color: Color = Z.lime

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Z.title(19))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                ZStack {
                    CutCorner().fill(Color.black).offset(x: 4, y: 4)
                    CutCorner().fill(configuration.isPressed ? Color.white : color)
                    CutCorner().stroke(Color.black, lineWidth: 3)
                }
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// 頁首：大標題 + 英文副標 + 警示條紋
struct ZHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(subtitle)
                .font(Z.mono(11))
                .foregroundColor(Z.lime)
            Text(title)
                .font(Z.title(32))
                .italic()
                .foregroundColor(Z.text)
            HazardStripes()
                .frame(width: 90, height: 8)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

/// 年份切換
struct YearSwitcher: View {
    @Binding var year: Int

    var body: some View {
        HStack(spacing: 16) {
            button("chevron.left") { year -= 1 }
            Text(Words.year(year))
                .font(Z.title(26))
                .foregroundColor(Z.text)
                .frame(minWidth: 120)
            button("chevron.right") { year += 1 }
        }
        .frame(maxWidth: .infinity)
    }

    private func button(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button {
            Z.haptic(.light)
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.black)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Z.lime))
                .overlay(Circle().stroke(Color.black, lineWidth: 3))
        }
    }
}

/// 分段選擇
struct ZSegments<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { i in
                let item = items[i]
                Button {
                    Z.haptic(.light)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = item.0 }
                } label: {
                    Text(item.1)
                        .font(Z.title(16))
                        .foregroundColor(selection == item.0 ? .black : Z.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(selection == item.0 ? Z.lime : Z.panel2))
                }
            }
        }
        .padding(5)
        .background(Capsule().fill(Color.black))
    }
}

/// 平行四邊形（左下、右上斜切）
struct Slant: Shape {
    var skew: CGFloat = 14

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

/// 合盤橫條：左＝合盤靈數膠囊、右＝兩人名字膠囊（電視螢幕風）
struct SynastryBar: View {
    let names: String
    let number: Int
    let numberLabel: String

    var body: some View {
        HStack(spacing: 10) {
            pill {
                VStack(spacing: 0) {
                    Text(numberLabel)
                        .font(Z.mono(9))
                        .foregroundColor(Z.lime)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(number)")
                        .font(Z.title(34))
                        .foregroundColor(Z.text)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
            }
            .frame(width: 112)

            pill {
                Text(names)
                    .font(Z.title(24))
                    .foregroundColor(Z.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 18)
            }
        }
        .frame(height: 100)
    }

    /// 外層深灰膠囊＋內層螢光框掃描線螢幕
    private func pill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Capsule().fill(Color.black)
            Capsule().stroke(Z.panel2, lineWidth: 6)
            ZStack {
                Capsule().fill(Z.lime.opacity(0.16))
                Canvas { ctx, size in
                    var y: CGFloat = 0
                    while y < size.height {
                        ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                                 with: .color(Color.black.opacity(0.28)))
                        y += 3
                    }
                }
                .clipShape(Capsule())
                Capsule().stroke(Z.lime, lineWidth: 3)
                content()
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
