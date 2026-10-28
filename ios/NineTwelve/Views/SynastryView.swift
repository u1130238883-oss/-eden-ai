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
    /// 名字合盤的結果：輸入的名字，以及對應到的本命宮位。
    @State private var nameResult: (name: String, rows: [PalaceRow])?

    private var t: T { state.t }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let mine = state.destiny {

                        Card(title: t("對方的名字", "The other person's name",
    "El nombre de la otra persona",
    "Il nome dell'altra persona")) {
                            VStack(spacing: 14) {
                                BirthInputView(name: $name, year: $year, month: $month,
                                               day: $day, lang: state.lang, forOther: true,
                                               onNameSynastry: {
                                                   result = nil
                                                   nameResult = (name: name, rows: mine.nameRows(name))
                                               })
                                Button {
                                    nameResult = nil
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

                        if let s = result {
                            resultSection(s: s)
                        }

                        if let n = nameResult {
                            nameSection(name: n.name, rows: n.rows, mine: mine)
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

    /// 名字合盤：名字對應到的本命宮位，點開可看引動。
    @ViewBuilder
    private func nameSection(name: String, rows: [PalaceRow], mine: Destiny) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: t("名字合盤", "Name synastry",
    "Sinastría del nombre",
    "Sinastria del nome") + " — " + name.trimmingCharacters(in: .whitespaces))
            if rows.isEmpty {
                Text(t("請輸入英文字母。", "Please enter English letters.",
    "Introduce letras del alfabeto inglés.",
    "Inserisci lettere dell'alfabeto inglese."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            } else {
                ChartTable(rows: rows,
                           lang: state.lang,
                           triggersFor: { .natalPalace(rows[$0].palace, in: mine) },
                           chipTap: .triggers)
                Text(t("點任一列可看詳細。", "Tap any row for detail.",
    "Toca cualquier fila para ver el detalle.",
    "Tocca una riga per il dettaglio."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
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
