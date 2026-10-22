import SwiftUI
import UIKit

/// 卡片容器。
struct Card<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CardBackground())
    }
}

/// 「好3因8」／「Favorable 3 from 8」的色塊。
struct VerdictBadge: View {
    let reading: Reading
    let lang: Lang
    var compact = false

    private var t: T { T(lang) }

    var body: some View {
        let color = Theme.color(for: reading.verdict)
        let size: CGFloat = compact ? 12 : 14
        HStack(spacing: 4) {
            Text(t.verdict(reading.verdict))
                .fontWeight(.bold)
            Text("\(reading.result)")
                .fontWeight(.bold)
            Text(t.causeParticle)
                .font(.system(size: size * 0.85))
                .opacity(0.78)
            Text("\(reading.cause)")
                .fontWeight(.semibold)
        }
        .font(.system(size: size))
        .monospacedDigit()
        .lineLimit(1)
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            Capsule().fill(color)
        )
    }
}

/// 宮位圓標：五行色的圓，白色數字，下面一行小字是五行。
struct PalaceChip: View {
    let palace: Int
    var lang: Lang = .zh
    var highlighted = false

    var body: some View {
        let element = Element.of(palace: palace)
        VStack(spacing: 0) {
            Text("\(palace)")
                .font(.system(size: 16, weight: .bold))
                .monospacedDigit()
            Text(element.name(lang))
                .font(.system(size: lang == .zh ? 8 : 6, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .frame(width: 38, height: 38)
        .background(Circle().fill(Theme.color(for: element)))
        .overlay(
            Circle().strokeBorder(Theme.accent, lineWidth: highlighted ? 2.5 : 0)
        )
    }
}

/// 標籤 + 數值的一行。
struct LabeledLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.trailing)
        }
    }
}
