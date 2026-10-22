import SwiftUI
import UIKit

/// 顏色與共用外觀，App 與桌面小工具共用。
/// 顏色：系統灰白底、金棕主色，跟著手機的淺色／深色模式。
enum Theme {

    static func color(for verdict: Verdict) -> Color {
        switch verdict {
        case .good:    return Color(red: 0.133, green: 0.600, blue: 0.420)
        case .neutral: return Color(red: 0.161, green: 0.451, blue: 0.780)
        case .bad:     return Color(red: 0.780, green: 0.278, blue: 0.239)
        }
    }

    static func color(for element: Element) -> Color {
        switch element {
        case .metal: return Color(red: 0.549, green: 0.569, blue: 0.620)
        case .wood:  return Color(red: 0.251, green: 0.580, blue: 0.341)
        case .water: return Color(red: 0.200, green: 0.478, blue: 0.722)
        case .fire:  return Color(red: 0.800, green: 0.341, blue: 0.259)
        case .earth: return Color(red: 0.659, green: 0.502, blue: 0.239)
        }
    }

    /// 淺色／深色模式各一種顏色。
    static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    /// 主色（UIKit 用）：金棕，深色模式時亮一點
    static let accentUI = dynamic(light: UIColor(red: 0.620, green: 0.451, blue: 0.161, alpha: 1),
                                  dark: UIColor(red: 0.776, green: 0.604, blue: 0.259, alpha: 1))
    /// 主色：金棕
    static let accent = Color(accentUI)
    /// 點綴：和主色相同
    static let gold = accent
    /// 主色底上的字
    static let onAccent = Color.white

    /// 頁面底色（系統分組背景）
    static let page = Color(UIColor.systemGroupedBackground)
    /// 卡片底色
    static let card = Color(UIColor.secondarySystemGroupedBackground)
    /// 卡片內的次一層底色
    static let inset = Color(UIColor.tertiarySystemFill)
    /// 細分隔線
    static let hairline = Color(UIColor.separator)
}

/// 卡片的形狀：大圓角。
struct CardShape: Shape {
    var radius: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }
}

/// 卡片背景：卡片底色、圓角。
struct CardBackground: View {
    var radius: CGFloat = 16

    var body: some View {
        CardShape(radius: radius)
            .fill(Theme.card)
    }
}

/// 頁面背景。
struct PageBackground: View {
    var body: some View {
        Theme.page.ignoresSafeArea()
    }
}

/// 區塊標題。
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

/// 主要按鈕：主色底、白字。
struct PrimaryButtonLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                CardShape(radius: 14)
                    .fill(Theme.accent)
            )
    }
}
