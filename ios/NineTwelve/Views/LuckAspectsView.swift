import SwiftUI

/// 一段大運的十二個方面。
///
/// 以該大運最後一年的年運為第一宮，往下接滿十二宮；
/// 第 N 宮就用第 N 宮的含義去讀。
struct LuckAspectsView: View {
    let period: LuckPeriod
    let aspects: [LuckAspect]
    let lang: Lang
    /// 點開最上面那張卡時，詳情頁要列出的引動。
    var periodTriggers: TriggerList? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var showingPeriod = false

    private var t: T { T(lang) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Card(title: period.span,
                     subtitle: t("這一段大運的十二個方面",
                                 "The twelve aspects of this pillar",
                                 "Los doce aspectos de este pilar",
                                 "I dodici aspetti di questo pilastro")) {
                    HStack(spacing: 12) {
                        PalaceChip(palace: period.row.palace, lang: lang)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.palaceNamed(period.row.palace))
                                .font(.subheadline.weight(.semibold))
                            Text(t.triple(period.row.triple))
                                .font(.system(.caption, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VerdictBadge(reading: period.row.reading, lang: lang, compact: true)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { showingPeriod = true }
                .sheet(isPresented: $showingPeriod) {
                    NavigationStack {
                        RowDetailView(row: period.row, lang: lang, triggers: periodTriggers)
                    }
                    .presentationDetents([.medium, .large])
                }

                ForEach(aspects) { item in
                    AspectRow(item: item, lang: lang)
                }
            }
            .padding(16)
        }
        .background(PageBackground())
        .navigationTitle(t("大運十二方面", "Twelve aspects",
                           "Los doce aspectos", "I dodici aspetti"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(t("完成", "Done", "Listo", "Fatto")) { dismiss() }
            }
        }
    }
}

/// 十二方面裡的一列。左邊是第幾宮，右邊是那一宮的盤與判讀。
private struct AspectRow: View {
    let item: LuckAspect
    let lang: Lang

    @State private var showing = false

    private var t: T { T(lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // 這裡的數字是「第幾個方面」，也就是要用哪一宮的含義去讀
                PalaceChip(palace: item.aspect, lang: lang)

                VStack(alignment: .leading, spacing: 2) {
                    Text(t.palaceNamed(item.aspect))
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(t.triple(item.row.triple))
                        .font(.system(.caption, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 6)

                VerdictBadge(reading: item.row.reading, lang: lang, compact: true)
            }

            Text(Palace.brief(item.aspect, lang: lang))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(CardBackground())
        .contentShape(Rectangle())
        .onTapGesture { showing = true }
        .sheet(isPresented: $showing) {
            NavigationStack {
                RowDetailView(row: item.row, lang: lang, displayPalace: item.aspect)
            }
            .presentationDetents([.medium, .large])
        }
    }
}
