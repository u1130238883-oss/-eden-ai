import SwiftUI
import UIKit

/// 本命盤：十二列，首列為命宮，宮位逆序，末列即本命三柱。
struct NatalView: View {
    @EnvironmentObject private var state: AppState

    private var t: T { state.t }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                if let destiny = state.destiny {
                    VStack(spacing: 16) {

                        Card(title: t("本命三柱", "The three pillars",
    "Los tres pilares",
    "I tre pilastri"),
                             subtitle: t("\(t.date(destiny.birth)) → 年、月、日各自化約", "\(t.date(destiny.birth)) → year, month and day each reduced",
    "\(t.date(destiny.birth)) → año, mes y día reducidos por separado",
    "\(t.date(destiny.birth)) → anno, mese e giorno ridotti separatamente")) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    PillarBox(label: t("年", "Year",
    "Año",
    "Anno"),
                                              raw: "\(destiny.birth.year)",
                                              value: destiny.triple.year)
                                    PillarBox(label: t("月", "Month",
    "Mes",
    "Mese"),
                                              raw: "\(destiny.birth.month)",
                                              value: destiny.triple.month)
                                    PillarBox(label: t("日", "Day",
    "Día",
    "Giorno"),
                                              raw: "\(destiny.birth.day)",
                                              value: destiny.triple.day)
                                }
                                Divider()
                                LabeledLine(
                                    label: t("三柱相加（九進制）", "Sum of the three (base 9)",
    "Suma de los tres (base 9)",
    "Somma dei tre (base 9)"),
                                    value: "\(destiny.triple.year) + \(destiny.triple.month) + \(destiny.triple.day)"
                                        + " = \(destiny.triple.year + destiny.triple.month + destiny.triple.day)"
                                        + " → \(t.lifeNumber) \(destiny.lifeNumber)")
                                LabeledLine(label: t.lifePalace,
                                            value: t.palaceNamed(destiny.lifeNumber))
                            }
                        }

                        // 靈數幾就是第幾型人格
                        EnneagramCard(lifeNumber: destiny.lifeNumber, lang: state.lang)

                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: t("十二宮盤", "The twelve palaces",
    "Los doce palacios",
    "I dodici palazzi"))
                            ChartTable(rows: destiny.natalChart,
                                       lang: state.lang,
                                       highlightIndex: 0,
                                       triggersFor: { .natalPalace(destiny.natalChart[$0].palace, in: destiny) },
                                       chipTap: .triggers)
                            Text(t("點任一列可看詳細。", "Tap any row for detail.",
    "Toca cualquier fila para ver el detalle.",
    "Tocca una riga per il dettaglio."))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                        }
                        .id("palaces")

                    }
                    .padding(16)
                }
            }
            #if DEBUG
            // 自動截圖用：-uiScroll YES 直接捲到十二宮方格
            .onAppear {
                if UserDefaults.standard.bool(forKey: "uiScroll") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        proxy.scrollTo("palaces", anchor: .top)
                    }
                }
            }
            #endif
            }
            .background(PageBackground())
            .navigationTitle(t("命盤", "Chart",
    "Carta",
    "Carta"))
        }
    }
}

private struct PillarBox: View {
    let label: String
    let raw: String
    let value: Int

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
            Text(raw)
                .font(.system(size: 10))
                .lineLimit(1)
                .foregroundStyle(.secondary.opacity(0.7))
            Text("\(value)")
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.inset)
        )
    }
}
