import SwiftUI
import UIKit

/// 十二宮盤的表格。每列可點開看詳細判讀。
struct ChartTable: View {
    let rows: [PalaceRow]
    let lang: Lang
    /// 每列右側的附註（例如年份或月份）。
    var trailingLabels: [String] = []
    /// 需要高亮的列索引。
    var highlightIndex: Int? = nil
    /// 點開某一列時，詳情頁要列出的引動（例如流年引動的大運方面）。
    var triggersFor: ((Int) -> TriggerList?)? = nil
    /// 點左邊宮位圓圈時要開什麼。
    var chipTap: ChipTap = .detail

    /// 點開的那一列，連同它的引動一起記下來。
    /// （引動不能等詳情頁打開時才用「第幾列」去算：那時讀到的可能還是上一次的列，
    /// 2027 年那一列就會顯示成 2026 年的引動。）
    @State private var selected: SelectedRow?
    @State private var chipSheet: ChipSheet?

    private struct SelectedRow: Identifiable {
        let id = UUID()
        let row: PalaceRow
        let triggers: TriggerList?
    }

    var body: some View {
        listBody
        .sheet(item: $selected) { item in
            NavigationStack {
                RowDetailView(row: item.row, lang: lang, triggers: item.triggers)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $chipSheet) { item in
            NavigationStack {
                ChipSheetView(item: item, lang: lang)
            }
            .presentationDetents([.medium, .large])
        }
    }

    /// 點了第 idx 列的宮位圓圈。
    private func tapChip(_ idx: Int, _ row: PalaceRow) {
        if let item = ChipSheet.make(chipTap, palace: row.palace,
                                     triggers: triggersFor?(idx)) {
            chipSheet = item
        } else {
            open(idx, row)
        }
    }

    /// 打開第 idx 列的完整詳情。
    private func open(_ idx: Int, _ row: PalaceRow) {
        selected = SelectedRow(row: row, triggers: triggersFor?(idx))
    }

    private var listBody: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                Button {
                    open(idx, row)
                } label: {
                    ChartTableRow(
                        row: row,
                        lang: lang,
                        trailing: idx < trailingLabels.count ? trailingLabels[idx] : nil,
                        highlighted: idx == highlightIndex,
                        onChipTap: { tapChip(idx, row) }
                    )
                }
                .buttonStyle(.plain)

                if idx < rows.count - 1 {
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 1)
                        .padding(.leading, 54)
                }
            }
        }
        .clipShape(CardShape())
        .background(CardBackground())
    }
}

private struct ChartTableRow: View {
    let row: PalaceRow
    let lang: Lang
    let trailing: String?
    let highlighted: Bool
    let onChipTap: () -> Void

    private var t: T { T(lang) }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onChipTap) {
                PalaceChip(palace: row.palace, lang: lang, highlighted: highlighted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(t.triple(row.triple))
                        .font(.subheadline)
                        .monospacedDigit()
                        .lineLimit(1)
                    if let trailing {
                        Text(trailing)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.accent.opacity(0.14)))
                    }
                }
                Text(Palace.brief(row.palace, lang: lang))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VerdictBadge(reading: row.reading, lang: lang, compact: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(highlighted ? Theme.accent.opacity(0.10) : Color.clear)
        .contentShape(Rectangle())
    }
}

/// 點宮位圓圈時要開什麼。
enum ChipTap {
    /// 跟點整列一樣，開完整詳情
    case detail
    /// 只開那一宮的含義
    case meaning
    /// 有引動就只開引動；沒有引動就跟點整列一樣
    case triggers
}

/// 點宮位圓圈後彈出的內容。
struct ChipSheet: Identifiable {
    enum Kind {
        case meaning(Int)
        case triggers(TriggerList)
    }

    let id = UUID()
    let kind: Kind

    /// 依設定決定要彈出什麼；回傳 nil 表示照舊開完整詳情。
    static func make(_ tap: ChipTap, palace: Int, triggers: TriggerList?) -> ChipSheet? {
        switch tap {
        case .detail:
            return nil
        case .meaning:
            return ChipSheet(kind: .meaning(palace))
        case .triggers:
            guard let triggers, !triggers.items.isEmpty else { return nil }
            return ChipSheet(kind: .triggers(triggers))
        }
    }
}

/// 宮位圓圈彈出的畫面：宮位含義，或引動。
struct ChipSheetView: View {
    let item: ChipSheet
    let lang: Lang
    @Environment(\.dismiss) private var dismiss

    private var t: T { T(lang) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch item.kind {
                case .meaning(let palace):
                    Card {
                        HStack(spacing: 14) {
                            PalaceChip(palace: palace, lang: lang, highlighted: true)
                            Text(t.palaceNamed(palace))
                                .font(.title3.weight(.bold))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                    Card {
                        Text(Palace.text(palace, lang: lang))
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .triggers(let triggers):
                    TriggerCard(triggers: triggers, lang: lang)
                }
            }
            .padding(16)
        }
        .background(PageBackground())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(t("完成", "Done", "Listo", "Fatto")) { dismiss() }
            }
        }
    }

    private var title: String {
        switch item.kind {
        case .meaning(let palace): return t.palace(palace)
        case .triggers(let triggers): return TriggerCard.title(triggers.kind, t)
        }
    }
}

/// 單列的完整判讀說明。
struct RowDetailView: View {
    let row: PalaceRow
    let lang: Lang
    /// 這一列要以哪一宮的含義去讀。大運十二方面用「第幾個方面」，
    /// 其餘畫面就是這一列本身的宮位。
    var displayPalace: Int? = nil
    /// 這一列所引動的宮位（流年 → 大運方面；大運 → 本命）。
    var triggers: TriggerList? = nil
    @Environment(\.dismiss) private var dismiss

    private var t: T { T(lang) }

    /// 實際呈現的宮位。
    private var palace: Int { displayPalace ?? row.palace }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // 頂部：宮位、三柱、判定
                Card {
                    HStack(spacing: 14) {
                        PalaceChip(palace: palace, lang: lang, highlighted: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.palaceNamed(palace))
                                .font(.title3.weight(.bold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text(t.triple(row.triple))
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 6)
                        VerdictBadge(reading: row.reading, lang: lang)
                    }
                }

                Card {
                    CauseEffectFlow(row: row, lang: lang, displayPalace: palace)
                }

                // 沒有引動就整張卡不顯示
                if let triggers, !triggers.items.isEmpty {
                    TriggerCard(triggers: triggers, lang: lang)
                }

                Card(title: "\(t.effectWord) — \(t.palaceNamed(row.reading.result))",
                     subtitle: t("事情呈現出來的樣子", "How it shows up",
    "Cómo se manifiesta",
    "Come si manifesta")) {
                    Text(Palace.text(row.reading.result, lang: lang))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Card(title: "\(t.causeWord) — \(t.palaceNamed(row.reading.cause))",
                     subtitle: t("事情背後的起因", "What lies behind it",
    "Qué hay detrás",
    "Che cosa c'è dietro")) {
                    Text(Palace.text(row.reading.cause, lang: lang))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Card(title: t("宮位本身", "The palace itself",
    "El palacio en sí",
    "Il palazzo in sé") + " — " + t.palace(palace),
                     subtitle: t("這件事發生的場域", "The arena it plays out in",
    "El terreno donde ocurre",
    "L'ambito in cui si svolge")) {
                    Text(Palace.text(palace, lang: lang))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .background(PageBackground())
        .navigationTitle("\(t.palace(palace)) \(t.reading(row.reading))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(t("完成", "Done",
    "Listo",
    "Fatto")) { dismiss() }
            }
        }
    }
}

/// 詳情頁裡「引動」那一段要列出的東西。
struct TriggerList {
    enum Kind { case luckAspects, natal }

    let kind: Kind
    /// 被引動的那一段大運的年份（只有流年引動大運方面時才有）。
    var span: String? = nil
    /// 每一項：以哪一宮去讀，以及那一列。
    let items: [(palace: Int, row: PalaceRow)]

    /// 某一年的流年所引動的大運方面。
    static func year(_ y: Int, in destiny: Destiny) -> TriggerList {
        TriggerList(kind: .luckAspects,
                    span: destiny.luckPeriod(containing: y).span,
                    items: destiny.triggeredAspects(forYear: y).map { (palace: $0.aspect, row: $0.row) })
    }

    /// 本命盤某一宮所引動的本命宮位。
    static func natalPalace(_ palace: Int, in destiny: Destiny) -> TriggerList {
        TriggerList(kind: .natal,
                    items: destiny.triggeredNatalRows(forPalace: palace).map { (palace: $0.palace, row: $0) })
    }

    /// 某一段大運所引動的本命宮位。
    static func luck(_ p: LuckPeriod, in destiny: Destiny) -> TriggerList {
        TriggerList(kind: .natal,
                    items: destiny.triggeredNatalRows(for: p).map { (palace: $0.palace, row: $0) })
    }
}

/// 引動的那幾宮。每一項可點開看那一宮的詳情。
private struct TriggerCard: View {
    let triggers: TriggerList
    let lang: Lang

    private var t: T { T(lang) }

    private var title: String { Self.title(triggers.kind, t) }

    static func title(_ kind: TriggerList.Kind, _ t: T) -> String {
        switch kind {
        case .luckAspects:
            return t("引動大運", "Luck Pillar aspects triggered",
                     "Aspectos del pilar activados", "Aspetti del pilastro attivati")
        case .natal:
            return t("引動本命", "Natal palaces triggered",
                     "Palacios natales activados", "Palazzi natali attivati")
        }
    }

    var body: some View {
        Card(title: title, subtitle: triggers.span) {
            VStack(spacing: 10) {
                ForEach(Array(triggers.items.enumerated()), id: \.offset) { idx, item in
                    NavigationLink {
                        RowDetailView(row: item.row, lang: lang, displayPalace: item.palace)
                    } label: {
                        HStack(spacing: 12) {
                            PalaceChip(palace: item.palace, lang: lang, highlighted: true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.palaceNamed(item.palace))
                                    .font(.subheadline.weight(.semibold))
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(t.triple(item.row.triple))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 6)
                            VerdictBadge(reading: item.row.reading, lang: lang, compact: true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if idx < triggers.items.count - 1 {
                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(height: 1)
                            .padding(.leading, 50)
                    }
                }
            }
        }
    }
}
