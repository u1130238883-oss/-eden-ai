import SwiftUI
import UIKit

/// 出生資料輸入（姓名 + 年月日），即時顯示算出的三柱與靈數。
struct BirthInputView: View {
    @Binding var name: String
    @Binding var year: Int
    @Binding var month: Int
    @Binding var day: Int
    var lang: Lang = .zh
    var showsName: Bool = true
    /// 合盤用：稱呼後面加冒號，不顯示「例如：自己」
    var forOther: Bool = false
    /// 合盤用：稱呼底下的「開始合盤」（名字合盤）。
    var onNameSynastry: (() -> Void)? = nil

    private var t: T { T(lang) }

    private var maxDay: Int {
        var c = DateComponents()
        c.year = year
        c.month = month
        let cal = Calendar(identifier: .gregorian)
        guard let d = cal.date(from: c),
              let range = cal.range(of: .day, in: .month, for: d) else { return 31 }
        return range.count
    }

    private var triple: Triple {
        BirthDate(year: year, month: month, day: day).triple
    }

    var body: some View {
        VStack(spacing: 14) {
            if showsName {
                HStack {
                    Text(forOther
                         ? t("稱呼：", "Name:", "Nombre:", "Nome:")
                         : t("稱呼", "Name",
    "Nombre",
    "Nome"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: lang == .zh ? (forOther ? 52 : 44) : (forOther ? 62 : 52),
                               alignment: .leading)
                    TextField(forOther
                              ? ""
                              : t("例如：自己", "e.g. Me",
    "p. ej. Yo",
    "es. Io"), text: $name)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.inset)
                )

                if let onNameSynastry {
                    Button(action: onNameSynastry) {
                        PrimaryButtonLabel(text: t("開始合盤", "Start synastry",
    "Iniciar sinastría",
    "Avvia sinastria"))
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            HStack(spacing: 0) {
                NumberWheel(title: t("年", "Year",
    "Año",
    "Anno"), value: $year, range: 1900...2100, width: 96)
                NumberWheel(title: t("月", "Month",
    "Mes",
    "Mese"), value: $month, range: 1...12, width: 68)
                NumberWheel(title: t("日", "Day",
    "Día",
    "Giorno"), value: $day, range: 1...maxDay, width: 68)
            }
            .frame(height: 132)
            .onChange(of: month) { _ in clampDay() }
            .onChange(of: year) { _ in clampDay() }

            HStack(spacing: 10) {
                PillarSummary(label: t.yearPillar, value: triple.year)
                PillarSummary(label: t.monthPillar, value: triple.month)
                PillarSummary(label: t.dayPillar, value: triple.day)

                VStack(spacing: 4) {
                    Text(t.lifeNumber)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(Theme.onAccent.opacity(0.8))
                    Text("\(triple.lifeNumber)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.onAccent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.accent)
                )
            }
        }
    }

    private func clampDay() {
        if day > maxDay { day = maxDay }
    }
}

private struct PillarSummary: View {
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.inset)
        )
    }
}

private struct NumberWheel: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let width: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
            Picker(title, selection: $value) {
                ForEach(Array(range), id: \.self) { n in
                    Text(verbatim: "\(n)")
                        .monospacedDigit()
                        .tag(n)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: width)
            .clipped()
        }
    }
}

/// 首次啟動時的輸入畫面。
struct OnboardingView: View {
    @EnvironmentObject private var state: AppState

    @State private var name = ""
    @State private var year = 2000
    @State private var month = 1
    @State private var day = 1

    private var t: T { state.t }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text(t("九型十二宮", "Nine & Twelve",
    "Nueve y Doce",
    "Nove e Dodici"))
                        .font(.system(size: 30, weight: .bold, design: .serif))
                    Text(t("輸入你的出生年月日，排出命盤", "Enter your date of birth to cast your chart",
    "Introduce tu fecha de nacimiento para trazar tu carta",
    "Inserisci la tua data di nascita per tracciare la carta"))
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)

                Picker("", selection: $state.lang) {
                    ForEach(Lang.available, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                Card {
                    BirthInputView(name: $name, year: $year, month: $month, day: $day, lang: state.lang)
                }

                Button {
                    state.owner = Profile(name: name,
                                          birth: BirthDate(year: year, month: month, day: day))
                } label: {
                    PrimaryButtonLabel(text: t("排盤", "Cast chart",
    "Trazar carta",
    "Traccia la carta"))
                }

                Text(t("資料只儲存在這台裝置上，不會上傳。", "Your data stays on this device and is never uploaded.",
    "Tus datos se quedan en este dispositivo y nunca se envían a ningún sitio.",
    "I tuoi dati restano su questo dispositivo e non vengono mai inviati altrove."))
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(PageBackground())
    }
}
