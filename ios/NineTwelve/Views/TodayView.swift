import SwiftUI
import UIKit

/// 今日總覽：白天／晚上日運、當月月運、今年流年、當前大運。
struct TodayView: View {
    @EnvironmentObject private var state: AppState
    @State private var date = Date()

    private var t: T { state.t }
    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let destiny = state.destiny {
                    content(destiny)
                        .padding(16)
                }
            }
            .background(PageBackground())
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                OverlayGuard.sample()
            }
            .navigationTitle(t("今日", "Today",
    "Hoy",
    "Oggi"))
        }
    }

    @ViewBuilder
    private func content(_ destiny: Destiny) -> some View {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 2026
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        let fortune = destiny.dayFortune(month: m, day: d)
        let yearRow = destiny.year(y)
        let monthRow = destiny.month(m, year: y)
        let luck = destiny.luckPeriod(containing: y)

        VStack(spacing: 16) {

            // 頂部：名字、生日、本命，右邊是靈數
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.owner?.displayName(state.lang) ?? t("本命", "Natal",
    "Natal",
    "Natale"))
                        .font(.headline.weight(.bold))
                    Text(t.date(destiny.birth)
                         + t("　\(max(0, y - destiny.birth.year))歲", "  ·  age \(max(0, y - destiny.birth.year))",
    "  ·  \(max(0, y - destiny.birth.year)) años",
    "  ·  \(max(0, y - destiny.birth.year)) anni"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(t("本命 ", "Natal ",
    "Natal ",
    "Natale ") + t.triple(destiny.triple))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text(t.lifeNumber)
                        .font(.system(size: 9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .opacity(0.85)
                    Text("\(destiny.lifeNumber)")
                        .font(.system(size: 26, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(Circle().fill(Theme.accent))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardBackground())

            DatePicker(t("日期", "Date",
    "Fecha",
    "Data"), selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(CardBackground())

            // fixedSize 讓這一列取兩張卡中較高的那個高度，
            // 兩張卡再各自撐滿 —— 不論關鍵字長短，版面都一樣大。
            HStack(spacing: 12) {
                DayCard(icon: "sun.max.fill",
                        title: t("白天日運", "Daytime",
    "Día",
    "Giorno"),
                        palace: fortune.dayPalace,
                        scale: t("十二進制", "base 12",
    "base 12",
    "base 12"),
                        lang: state.lang)
                DayCard(icon: "moon.stars.fill",
                        title: t("晚上日運", "Night",
    "Noche",
    "Notte"),
                        palace: fortune.nightPalace,
                        scale: t("九進制", "base 9",
    "base 9",
    "base 9"),
                        lang: state.lang)
            }
            .fixedSize(horizontal: false, vertical: true)

            SummaryCard(title: t("\(m)月月運", "\(t.month(m)) — monthly luck",
    "\(t.month(m)) — suerte mensual",
    "\(t.month(m)) — sorte mensile"),
                        caption: t("\(y)年 第\(m)個月", "Month \(m) of \(y)",
    "Mes \(m) de \(y)",
    "Mese \(m) del \(y)"),
                        row: monthRow.row,
                        lang: state.lang,
                        chipTap: .meaning)

            SummaryCard(title: t("\(y)年流年", "\(y) — annual luck",
    "\(y) — suerte anual",
    "\(y) — sorte annuale"),
                        caption: t("\(y)年整年的運勢", "The reading for the whole of \(y)",
    "La lectura de todo el año \(y)",
    "La lettura di tutto l'anno \(y)"),
                        row: yearRow,
                        lang: state.lang,
                        triggers: .year(y, in: destiny),
                        chipTap: .triggers)

            SummaryCard(title: t("當前大運", "Current luck pillar",
    "Pilar de Suerte actual",
    "Pilastro della Sorte attuale"),
                        caption: t("\(luck.span)（\(luck.length)年）", "\(luck.span) (\(luck.length) yrs)",
    "\(luck.span) (\(luck.length) años)",
    "\(luck.span) (\(luck.length) anni)"),
                        row: luck.row,
                        lang: state.lang,
                        triggers: .luck(luck, in: destiny),
                        chipTap: .triggers)

            ShareLink(item: summaryText(destiny, y: y, m: m, d: d,
                                        fortune: fortune, yearRow: yearRow,
                                        monthRow: monthRow.row, luck: luck)) {
                Label(t("分享這一天的推算", "Share this day's reading",
    "Compartir la lectura de este día",
    "Condividi la lettura di questo giorno"),
                      systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(CardBackground(radius: 16))
            }
            .foregroundStyle(Theme.accent)
            .padding(.top, 4)
        }
    }

    /// 把當天的推算整理成純文字，方便貼給別人看。
    private func summaryText(_ destiny: Destiny, y: Int, m: Int, d: Int,
                             fortune: DayFortune, yearRow: PalaceRow,
                             monthRow: PalaceRow, luck: LuckPeriod) -> String {
        func line(_ label: String, _ row: PalaceRow) -> String {
            "\(label)：\(t.palaceNamed(row.palace))  \(t.triple(row.triple))  \(t.reading(row.reading))"
        }
        let head = t("九型十二宮 · \(y)年\(m)月\(d)日", "Nine & Twelve · \(d) \(t.month(m)) \(y)",
    "Nueve y Doce · \(d) \(t.month(m)) \(y)",
    "Nove e Dodici · \(d) \(t.month(m)) \(y)")
        return [
            head,
            t("本命 \(t.triple(destiny.triple))　\(t.lifeNumber) \(destiny.lifeNumber)", "Natal \(t.triple(destiny.triple)) · \(t.lifeNumber) \(destiny.lifeNumber)",
    "Natal \(t.triple(destiny.triple)) · \(t.lifeNumber) \(destiny.lifeNumber)",
    "Natale \(t.triple(destiny.triple)) · \(t.lifeNumber) \(destiny.lifeNumber)"),
            "",
            t("白天：\(t.palaceNamed(fortune.dayPalace))", "Daytime: \(t.palaceNamed(fortune.dayPalace))",
    "Día: \(t.palaceNamed(fortune.dayPalace))",
    "Giorno: \(t.palaceNamed(fortune.dayPalace))"),
            t("晚上：\(t.palaceNamed(fortune.nightPalace))", "Night: \(t.palaceNamed(fortune.nightPalace))",
    "Noche: \(t.palaceNamed(fortune.nightPalace))",
    "Notte: \(t.palaceNamed(fortune.nightPalace))"),
            line(t("月運", "Monthly",
    "Mensual",
    "Mensile"), monthRow),
            line(t("流年", "Annual",
    "Anual",
    "Annuale"), yearRow),
            line(t("大運 \(luck.span)", "Luck Pillar \(luck.span)",
    "Pilar de Suerte \(luck.span)",
    "Pilastro della Sorte \(luck.span)"), luck.row),
        ].joined(separator: "\n")
    }

}

private struct DayCard: View {
    let icon: String
    let title: String
    let palace: Int
    let scale: String
    let lang: Lang

    private var t: T { T(lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Theme.accent)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(palace)")
                    .font(.system(size: 38, weight: .bold))
                    .monospacedDigit()
                Text(t("宮", "palace",
    "palacio",
    "palazzo"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Text(Palace.shortName(palace, lang: lang))
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            Text(Palace.brief(palace, lang: lang))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // 把進制標註推到底部，兩張卡的底線才會對齊
            Spacer(minLength: 4)

            Text(scale)
                .font(.system(size: 9))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CardBackground())
    }
}

/// 「某一段時間走哪一宮」的摘要卡，可點開看詳細。
struct SummaryCard: View {
    let title: String
    let caption: String
    let row: PalaceRow
    let lang: Lang
    /// 給大運用：點左邊那個圓圈時要開的東西。沒給的話圓圈跟著整張卡走。
    var onPalaceTap: (() -> Void)?
    /// 點開詳情時要列出的引動。
    var triggers: TriggerList? = nil
    /// 點左邊宮位圓圈時要開什麼（有給 onPalaceTap 時以它為準）。
    var chipTap: ChipTap = .detail

    @State private var showing = false
    @State private var chipSheet: ChipSheet?

    private var t: T { T(lang) }

    var body: some View {
        Button {
            // 日曆開著時，這一下只是用來關掉日曆
            if OverlayGuard.isShowing { return }
            showing = true
        } label: {
            card
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showing) {
            NavigationStack {
                RowDetailView(row: row, lang: lang, triggers: triggers)
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

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 標題列
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 宮位、三柱、判定
            HStack(spacing: 12) {
                Button {
                    // 日曆開著時，這一下只是用來關掉日曆
                    if OverlayGuard.isShowing { return }
                    if let onPalaceTap {
                        onPalaceTap()
                    } else if let item = ChipSheet.make(chipTap, palace: row.palace,
                                                        triggers: triggers) {
                        chipSheet = item
                    } else {
                        showing = true
                    }
                } label: {
                    PalaceChip(palace: row.palace, lang: lang, highlighted: true)
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.palaceNamed(row.palace))
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(t.triple(row.triple))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)
                VerdictBadge(reading: row.reading, lang: lang, compact: true)
            }

            // 果與因
            VStack(alignment: .leading, spacing: 6) {
                Text("\(t.effectWord) \(t.palaceNamed(row.reading.result))"
                     + t("　·　", "  ·  ",
    "  ·  ",
    "  ·  ")
                     + "\(t.causeWord) \(t.palaceNamed(row.reading.cause))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Palace.brief(row.reading.result, lang: lang))
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CardBackground())
        .contentShape(Rectangle())
    }
}

/// 日期選擇器的小日曆是浮在畫面上的；點旁邊把它關掉的那一下，
/// 會落到下面的卡片上。卡片被點時先問這裡：小日曆還開著、正在收起、
/// 或剛收起不到半秒，就不理這一下。
enum OverlayGuard {
    /// 上一次看到小日曆開著的時間（今日頁每 0.1 秒看一次）。
    private static var lastSeen = Date.distantPast

    /// 今日頁定時呼叫，記下小日曆是否開著。
    static func sample() {
        if overlayOnScreen { lastSeen = Date() }
    }

    static var isShowing: Bool {
        if overlayOnScreen { return true }
        return Date().timeIntervalSince(lastSeen) < 0.5
    }

    private static var overlayOnScreen: Bool {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where !window.isHidden {
                if window.rootViewController?.presentedViewController != nil { return true }
                if containsDatePickerOverlay(window, depth: 3) { return true }
            }
        }
        return false
    }

    /// 小日曆有時不是用「彈出畫面」的方式，而是直接加在視窗上，所以也看一下視窗裡的東西。
    private static func containsDatePickerOverlay(_ view: UIView, depth: Int) -> Bool {
        guard depth > 0 else { return false }
        for sub in view.subviews {
            let name = String(describing: type(of: sub))
            if name.contains("DatePicker") && name.contains("Overlay") { return true }
            if containsDatePickerOverlay(sub, depth: depth - 1) { return true }
        }
        return false
    }
}
