import SwiftUI
import UIKit

/// 一生大運的橫向時間軸。每段寬度與年數成比例，顏色是該段的判定，
/// 開啟時自動捲到現在所處的那一段。
struct LuckTimeline: View {
    let periods: [LuckPeriod]
    let birthYear: Int
    let currentYear: Int
    let lang: Lang
    /// 點開某一段大運時，詳情頁要列出的引動。
    var triggersFor: ((LuckPeriod) -> TriggerList)? = nil

    @State private var sheetPeriod: LuckPeriod?

    private var t: T { T(lang) }
    private let unit: CGFloat = 15   // 每一年的寬度

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(periods) { p in
                        segment(p)
                            .id(p.startYear)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .onAppear {
                if let now = periods.first(where: { $0.contains(currentYear) }) {
                    proxy.scrollTo(now.startYear, anchor: .center)
                }
            }
        }
        .sheet(item: $sheetPeriod) { p in
            NavigationStack {
                RowDetailView(row: p.row, lang: lang, triggers: triggersFor?(p))
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func segment(_ p: LuckPeriod) -> some View {
        let isNow = p.contains(currentYear)
        let startAge = max(0, p.startYear - birthYear)
        let endAge = max(0, p.endYear - birthYear)

        Button {
            sheetPeriod = p
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: "\(p.startYear)")
                    .font(.caption2.weight(isNow ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isNow ? Theme.accent : .secondary)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.color(for: p.row.reading.verdict))
                        .frame(height: 46)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(p.row.palace)")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(t.verdict(p.row.reading.verdict))
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isNow ? Theme.accent : .clear, lineWidth: 3)
                )

                Text(t("\(startAge)–\(endAge)歲", "age \(startAge)–\(endAge)",
    "\(startAge)–\(endAge) años",
    "\(startAge)–\(endAge) anni"))
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.secondary)
            }
            .frame(width: max(52, CGFloat(p.length) * unit))
        }
        .buttonStyle(.plain)
    }
}

/// 因 → 果 的小圖，說明這一列的來龍去脈落在哪兩個宮。
struct CauseEffectFlow: View {
    let row: PalaceRow
    let lang: Lang
    /// 這件事發生的場域要以哪一宮去讀，預設就是這一列的宮位。
    var displayPalace: Int? = nil

    private var t: T { T(lang) }

    private var palace: Int { displayPalace ?? row.palace }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                node(palace: row.reading.cause, caption: t.causeWord)
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                node(palace: row.reading.result, caption: t.effectWord)
            }
            Text(t("發生在 \(t.palaceNamed(palace))", "playing out in \(t.palaceNamed(palace))",
    "ocurre en \(t.palaceNamed(palace))",
    "si svolge in \(t.palaceNamed(palace))"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func node(palace: Int, caption: String) -> some View {
        VStack(spacing: 5) {
            Text(caption)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            PalaceChip(palace: palace, lang: lang)
            Text(Palace.shortName(palace, lang: lang))
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: 92)
        }
    }
}
