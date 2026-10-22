import SwiftUI
import UIKit

/// 運程：大運 / 流年 / 月運。
struct FortuneView: View {
    @EnvironmentObject private var state: AppState
    @State private var tab: Segment = {
        #if DEBUG
        // 自動截圖用：-uiSeg year / month
        if let raw = UserDefaults.standard.string(forKey: "uiSeg"), let s = Segment(rawValue: raw) {
            return s
        }
        #endif
        return .luck
    }()
    @State private var year = Calendar(identifier: .gregorian).component(.year, from: Date())
    /// 點了哪一段大運的圓圈，就看那一段的十二個方面
    @State private var aspectsPeriod: LuckPeriod?

    enum Segment: String, CaseIterable {
        case luck, year, month

        func title(_ t: T) -> String {
            switch self {
            case .luck:  return t("大運", "Luck Pillars",
    "Pilares de Suerte",
    "Pilastri della Sorte")
            case .year:  return t("流年", "Annual",
    "Anual",
    "Annuale")
            case .month: return t("月運", "Monthly",
    "Mensual",
    "Mensile")
            }
        }
    }

    private var t: T { state.t }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 大運／流年／月運 切換
                Picker("", selection: $tab) {
                    ForEach(Segment.allCases, id: \.self) { seg in
                        Text(seg.title(t)).tag(seg)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                ScrollView {
                    if let destiny = state.destiny {
                        Group {
                            switch tab {
                            case .luck:  luckSection(destiny)
                            case .year:  yearSection(destiny)
                            case .month: monthSection(destiny)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(PageBackground())
            .navigationTitle(t("運程", "Fortune",
    "Destino",
    "Sorte"))
            .sheet(item: $aspectsPeriod) { p in
                NavigationStack {
                    if let destiny = state.destiny {
                        LuckAspectsView(period: p,
                                        aspects: destiny.luckAspects(containing: p.startYear),
                                        lang: state.lang,
                                        periodTriggers: .luck(p, in: destiny))
                    }
                }
            }
        }
    }

    // MARK: - 大運

    @ViewBuilder
    private func luckSection(_ destiny: Destiny) -> some View {
        let thisYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        let periods = destiny.luckPeriods(count: 11)

        VStack(spacing: 14) {
            Card(title: t("一生大運", "A lifetime of Luck Pillars",
    "Los Pilares de Suerte de toda una vida",
    "I Pilastri della Sorte di tutta una vita"),
                 subtitle: t("每段寬度即年數，外框是現在所處的一段", "Each block's width is its length; the outlined one is where you are now",
    "El ancho de cada bloque es su duración; el enmarcado es donde estás ahora",
    "La larghezza di ogni blocco è la sua durata; quello incorniciato è dove ti trovi adesso")) {
                LuckTimeline(periods: periods,
                             birthYear: destiny.birth.year,
                             currentYear: thisYear,
                             lang: state.lang,
                             triggersFor: { .luck($0, in: destiny) })
            }

            ForEach(periods) { p in
                SummaryCard(title: p.span,
                            caption: p.contains(thisYear)
                                ? t("現在所處的大運 · \(p.length)年", "Current pillar · \(p.length) yrs",
    "Pilar actual · \(p.length) años",
    "Pilastro attuale · \(p.length) anni")
                                : t("\(p.length)年", "\(p.length) yrs",
    "\(p.length) años",
    "\(p.length) anni"),
                            row: p.row,
                            lang: state.lang,
                            // 點左邊那個圓圈：看這段大運的十二個方面
                            onPalaceTap: { aspectsPeriod = p },
                            triggers: .luck(p, in: destiny))
                .overlay(alignment: .topTrailing) {
                    if p.contains(thisYear) {
                        Text(t("目前", "Now",
    "Ahora",
    "Ora"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.accent))
                            .padding(10)
                    }
                }
            }
        }
    }

    // MARK: - 流年

    @ViewBuilder
    private func yearSection(_ destiny: Destiny) -> some View {
        let start = year
        let labels = (0..<12).map { t.year(start + $0) }
        let rows = (0..<12).map { destiny.year(start + $0) }
        let thisYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        let highlight = (thisYear >= start && thisYear < start + 12) ? thisYear - start : nil

        VStack(spacing: 14) {
            YearStepper(year: $year,
                        title: t("由這一年起算十二年", "Twelve years from",
    "Doce años desde",
    "Dodici anni da"),
                        lang: state.lang,
                        birthYear: destiny.birth.year)

            ChartTable(rows: rows,
                       lang: state.lang,
                       trailingLabels: labels,
                       highlightIndex: highlight,
                       triggersFor: { .year(start + $0, in: destiny) },
                       chipTap: .triggers)
        }
    }

    // MARK: - 月運

    @ViewBuilder
    private func monthSection(_ destiny: Destiny) -> some View {
        let months = destiny.monthChart(year: year)
        let thisYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        let thisMonth = Calendar(identifier: .gregorian).component(.month, from: Date())
        let highlight = (year == thisYear) ? thisMonth - 1 : nil

        VStack(spacing: 14) {
            YearStepper(year: $year, title: t("選擇年份", "Year", "Año", "Anno"),
                        lang: state.lang, birthYear: destiny.birth.year)

            ChartTable(rows: months.map { $0.row },
                       lang: state.lang,
                       trailingLabels: months.map { t.month($0.month) },
                       highlightIndex: highlight,
                       chipTap: .meaning)
        }
    }
}

private struct YearStepper: View {
    @Binding var year: Int
    let title: String
    let lang: Lang
    var birthYear: Int? = nil

    private var thisYear: Int {
        Calendar(identifier: .gregorian).component(.year, from: Date())
    }

    var body: some View {
        let t = T(lang)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(t.year(year))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                    if let birthYear, year >= birthYear {
                        Text(t("\(year - birthYear)歲", "age \(year - birthYear)",
    "\(year - birthYear) años",
    "\(year - birthYear) anni"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if year != thisYear {
                        Button(t("回到今年", "Today",
    "Hoy",
    "Oggi")) { year = thisYear }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            Spacer()
            Stepper("", value: $year)
                .labelsHidden()
        }
        .padding(16)
        .background(CardBackground())
    }
}
