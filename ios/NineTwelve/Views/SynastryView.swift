import SwiftUI
import UIKit

/// 合盤：輸入另一個人的生日，兩盤三柱相加後排出十二宮。
struct SynastryView: View {
    @EnvironmentObject private var state: AppState

    @State private var name = ""
    @State private var year = 2000
    @State private var month = 1
    @State private var day = 1
    @State private var result: Synastry?

    private var t: T { state.t }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let mine = state.destiny {

                        Card(title: t("對方的出生資料", "The other person's birth details",
    "Datos de nacimiento de la otra persona",
    "Dati di nascita dell'altra persona")) {
                            VStack(spacing: 14) {
                                BirthInputView(name: $name, year: $year, month: $month,
                                               day: $day, lang: state.lang, forOther: true)
                                Button {
                                    let other = Profile(name: name,
                                                        birth: BirthDate(year: year, month: month, day: day))
                                    state.addOther(other)
                                    result = Synastry(a: mine,
                                                      b: other.destiny(anchor: state.yearAnchor))
                                } label: {
                                    PrimaryButtonLabel(text: t("合盤", "Combine charts",
    "Combinar cartas",
    "Combina le carte"))
                                }
                            }
                        }

                        if !state.others.isEmpty {
                            Card(title: t("最近合過的人", "Recently combined",
    "Combinados recientemente",
    "Combinati di recente")) {
                                VStack(spacing: 0) {
                                    ForEach(state.others) { p in
                                        Button {
                                            name = p.name
                                            year = p.birth.year
                                            month = p.birth.month
                                            day = p.birth.day
                                            result = Synastry(a: mine,
                                                              b: p.destiny(anchor: state.yearAnchor))
                                        } label: {
                                            HStack {
                                                Text(p.displayName(state.lang))
                                                    .font(.subheadline)
                                                Spacer()
                                                Text(t.date(p.birth))
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Image(systemName: "chevron.right")
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .padding(.vertical, 9)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        if p.id != state.others.last?.id { Divider() }
                                    }
                                }
                            }
                        }

                        if let s = result {
                            resultSection(s: s)
                        }
                    }
                }
                .padding(16)
            }
            .background(PageBackground())
            #if DEBUG
            // 自動截圖用：帶 -uiDemo YES 時直接排一個示範合盤
            .onAppear {
                if UserDefaults.standard.bool(forKey: "uiDemo"), result == nil, let mine = state.destiny {
                    result = Synastry(a: mine, b: Profile(name: "", birth: BirthDate(year: 1990, month: 6, day: 15)).destiny(anchor: state.yearAnchor))
                }
            }
            #endif
            .navigationTitle(t("合盤", "Synastry",
    "Sinastría",
    "Sinastria"))
        }
    }

    @ViewBuilder
    private func resultSection(s: Synastry) -> some View {

        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: t("合盤十二宮", "The combined twelve palaces",
    "Los doce palacios combinados",
    "I dodici palazzi combinati"))
            ChartTable(rows: s.chart, lang: state.lang, highlightIndex: 0,
                       chipTap: .meaning)
            Text(t("點任一列可看詳細。", "Tap any row for detail.",
    "Toca cualquier fila para ver el detalle.",
    "Tocca una riga per il dettaglio."))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }
}
