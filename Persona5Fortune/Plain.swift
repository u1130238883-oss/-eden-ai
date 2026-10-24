import SwiftUI

// 白話翻譯層：把宮位與判讀轉成一般人一看就懂的說法。

enum Topic {
    /// 每一宮的白話主題
    static func title(_ p: Int) -> String {
        let titles: [[String]] = [
            ["自己・情緒", "錢財・物質", "溝通・學習", "家庭・安全感",
             "戀愛・桃花", "忙碌・日常", "伴侶・人際", "偏財・身體",
             "好運・遠行", "事業・地位", "朋友・變動", "內心・隱藏"],
            ["Self · Emotions", "Money · Possessions", "Communication · Learning", "Home · Security",
             "Romance · Attraction", "Busyness · Routine", "Partner · Relationships", "Windfalls · Body",
             "Luck · Travel", "Career · Status", "Friends · Change", "Inner Self · Hidden"],
            ["Yo · Emociones", "Dinero · Bienes", "Comunicación · Estudio", "Hogar · Seguridad",
             "Amor · Atracción", "Ajetreo · Rutina", "Pareja · Relaciones", "Dinero extra · Cuerpo",
             "Suerte · Viajes", "Carrera · Estatus", "Amigos · Cambios", "Mundo interior · Oculto"],
            ["Io · Emozioni", "Denaro · Beni", "Comunicazione · Studio", "Casa · Sicurezza",
             "Amore · Attrazione", "Fatica · Routine", "Partner · Relazioni", "Denaro extra · Corpo",
             "Fortuna · Viaggi", "Carriera · Status", "Amici · Cambiamenti", "Interiorità · Nascosto"]
        ]
        return titles[Lang.current.index][Num.r12(p) - 1]
    }

    static func icon(_ p: Int) -> String {
        [
            "person.fill", "yensign.circle.fill", "bubble.left.and.bubble.right.fill", "house.fill",
            "heart.fill", "figure.walk", "person.2.fill", "cross.case.fill",
            "airplane", "briefcase.fill", "person.3.fill", "moon.fill"
        ][Num.r12(p) - 1]
    }

    /// 前三個關鍵詞
    static func hint(_ p: Int) -> String {
        let n = Palace.name(p)
        return Palace.keywords(p).filter { $0 != n }.prefix(3).joined(separator: Lang.current.separator)
    }
}

extension Verdict {
    /// 判讀依據
    var meaning: String {
        switch self {
        case .good: return L("年月相生", "Year and Month generate", "El Año y el Mes se generan", "L'Anno e il Mese si generano")
        case .neutral: return L("年月同行", "Year and Month share an element", "El Año y el Mes comparten elemento", "L'Anno e il Mese condividono l'elemento")
        case .bad: return L("年月相剋", "Year and Month control", "El Año y el Mes se dominan", "L'Anno e il Mese si dominano")
        }
    }

    var color: Color {
        switch self {
        case .good: return Z.lime
        case .neutral: return Z.cyan
        case .bad: return Z.orange
        }
    }
}

extension PalaceRow {
    /// 例如：果在 5宮・桃花，因在 3宮・交流
    var sentence: String {
        let r = reading
        return L("果在 \(r.result)宮・\(Palace.name(r.result))，因在 \(r.cause)宮・\(Palace.name(r.cause))",
                 "Effect in Palace \(r.result) · \(Palace.name(r.result)), cause in Palace \(r.cause) · \(Palace.name(r.cause))",
                 "Efecto en el Palacio \(r.result) · \(Palace.name(r.result)), causa en el Palacio \(r.cause) · \(Palace.name(r.cause))",
                 "Effetto nel Palazzo \(r.result) · \(Palace.name(r.result)), causa nel Palazzo \(r.cause) · \(Palace.name(r.cause))")
    }
}

/// 判讀標記：好5因3 / 正2因7 / 壞9因4
struct ReadingTag: View {
    let reading: Reading
    var big = false

    var body: some View {
        Text(reading.text)
            .font(.system(size: (big ? 30 : 17) * (Lang.current == .zh ? 1 : 0.8), weight: .black, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, big ? 18 : 10)
            .padding(.vertical, big ? 6 : 3)
            .background(Capsule().fill(reading.verdict.color))
            .overlay(Capsule().stroke(Color.black, lineWidth: 2))
            .fixedSize()
            .accessibilityLabel(reading.text)
    }
}

/// 「果 5 桃花 ← 因 3 交流」
struct CauseLine: View {
    let reading: Reading
    var dark = false

    var body: some View {
        HStack(spacing: 4) {
            part(Words.effect, reading.result)
            Image(systemName: "arrow.left")
                .font(.system(size: 10, weight: .black))
                .foregroundColor(dark ? .black : Z.dim)
            part(Words.cause, reading.cause)
        }
    }

    private func part(_ label: String, _ p: Int) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(Z.title(11))
                .foregroundColor(dark ? Z.lime : .black)
                .padding(.horizontal, 3)
                .background(RoundedRectangle(cornerRadius: 3).fill(dark ? Color.black : Z.text))
            Text("\(p) \(Palace.name(p))")
                .font(Z.title(13))
                .foregroundColor(dark ? .black : Z.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// 主題圖示方塊
struct TopicBadge: View {
    let palace: Int
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: Topic.icon(palace))
            .font(.system(size: size * 0.42, weight: .black))
            .foregroundColor(.black)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.28).fill(Z.lime))
            .overlay(RoundedRectangle(cornerRadius: size * 0.28).stroke(Color.black, lineWidth: 2.5))
    }
}

/// 列表中的一行：左標籤、果←因、判讀
struct SimpleRow: View {
    let label: String
    let row: PalaceRow
    var palace: Int? = nil
    var highlight = false
    let onTap: () -> Void

    var body: some View {
        Button {
            Z.haptic(.light)
            onTap()
        } label: {
            Group {
                if Lang.current == .zh {
                    HStack(spacing: 10) {
                        labelText
                        CauseLine(reading: row.reading, dark: highlight)
                        Spacer(minLength: 4)
                        ReadingTag(reading: row.reading)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            labelText
                            Spacer(minLength: 4)
                            ReadingTag(reading: row.reading)
                        }
                        CauseLine(reading: row.reading, dark: highlight)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 14).fill(highlight ? Z.lime : Z.panel2))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(highlight ? Color.black : Color.black, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private var labelText: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(Z.title(15))
                .foregroundColor(highlight ? .black : Z.lime)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let palace {
                Text("\(Words.palace(palace)) \(Palace.name(palace))")
                    .font(Z.title(11))
                    .foregroundColor(highlight ? .black.opacity(0.7) : Z.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(width: Lang.current == .zh ? 64 : nil, alignment: .leading)
    }
}

// MARK: - 詳細頁（白話版）

struct RowDetail: Identifiable {
    let id = UUID()
    let title: String
    let row: PalaceRow
    var sections: [DetailSection] = []
}

/// 詳細頁下方的附加清單（引動、大運十二方面）
struct DetailSection: Identifiable {
    let id = UUID()
    let title: String
    let note: String
    let items: [TriggerItem]
}

struct TriggerItem: Identifiable {
    let id = UUID()
    let label: String
    let row: PalaceRow
}

/// 引動推算（依原版）：
/// ・流年引動大運方面：大運十二方面（第 N 方面即 N 宮）中，果或因等於流年宮位者
/// ・大運引動本命宮：本命十二宮中，果或因等於大運宮位者
/// ・本命宮引動本命宮：其他本命宮中，果或因等於該宮位者
enum Triggers {
    static func natal(_ d: Destiny, _ r: PalaceRow) -> [DetailSection] {
        let p = r.palace
        let items = d.triggeredNatalRows(forPalace: p).map {
            TriggerItem(label: "\($0.palace) \(Palace.name($0.palace))", row: $0)
        }
        return [DetailSection(title: L("本命宮引動的本命宮", "Natal palaces triggered", "Palacios natales activados", "Palazzi natali attivati"),
                              note: L("本命 \(p)宮・\(Palace.name(p))：其他本命宮中果或因為 \(p) 者被引動",
                                      "Natal palace \(p) · \(Palace.name(p)): other natal palaces whose effect or cause is \(p) are triggered",
                                      "Palacio natal \(p) · \(Palace.name(p)): se activan los demás palacios natales cuyo efecto o causa es \(p)",
                                      "Palazzo natale \(p) · \(Palace.name(p)): si attivano gli altri palazzi natali il cui effetto o causa è \(p)"),
                              items: items)]
    }

    static func year(_ d: Destiny, _ y: Int) -> [DetailSection] {
        let yr = d.year(y)
        let items = d.triggeredAspects(forYear: y).map { TriggerItem(label: "\($0.aspect) \(Palace.name($0.aspect))", row: $0.row) }
        return [DetailSection(title: L("流年引動的大運方面", "Luck Pillar aspects triggered", "Aspectos del pilar activados", "Aspetti del pilastro attivati"),
                              note: L("流年 \(yr.palace)宮・\(Palace.name(yr.palace))：大運方面中果或因為 \(yr.palace) 者被引動",
                                      "Annual palace \(yr.palace) · \(Palace.name(yr.palace)): pillar aspects whose effect or cause is \(yr.palace) are triggered",
                                      "Palacio anual \(yr.palace) · \(Palace.name(yr.palace)): se activan los aspectos del pilar cuyo efecto o causa es \(yr.palace)",
                                      "Palazzo annuale \(yr.palace) · \(Palace.name(yr.palace)): si attivano gli aspetti del pilastro il cui effetto o causa è \(yr.palace)"),
                              items: items)]
    }

    static func luck(_ d: Destiny, _ p: LuckPeriod) -> [DetailSection] {
        let natal = d.triggeredNatalRows(for: p).map {
            TriggerItem(label: "\($0.palace) \(Palace.name($0.palace))", row: $0)
        }
        let aspects = d.luckAspects(containing: p.startYear).map {
            TriggerItem(label: "\($0.aspect) \(Palace.name($0.aspect))", row: $0.row)
        }
        return [
            DetailSection(title: L("大運引動的本命宮", "Natal palaces triggered", "Palacios natales activados", "Palazzi natali attivati"),
                          note: L("大運 \(p.row.palace)宮・\(Palace.name(p.row.palace))：本命宮中果或因為 \(p.row.palace) 者被引動",
                                  "Luck Pillar palace \(p.row.palace) · \(Palace.name(p.row.palace)): natal palaces whose effect or cause is \(p.row.palace) are triggered",
                                  "Palacio del pilar \(p.row.palace) · \(Palace.name(p.row.palace)): se activan los palacios natales cuyo efecto o causa es \(p.row.palace)",
                                  "Palazzo del pilastro \(p.row.palace) · \(Palace.name(p.row.palace)): si attivano i palazzi natali il cui effetto o causa è \(p.row.palace)"),
                          items: natal),
            DetailSection(title: L("這一段大運的十二個方面", "The twelve aspects of this pillar", "Los doce aspectos de este pilar", "I dodici aspetti di questo pilastro"),
                          note: "", items: aspects)
        ]
    }

    /// 列表下方的簡短提示
    static func summary(_ sections: [DetailSection]) -> String? {
        guard let first = sections.first, !first.items.isEmpty else { return nil }
        return L("引動：", "Triggered: ", "Activado: ", "Attivato: ")
            + first.items.map { "\($0.label) \($0.row.reading.text)" }.joined(separator: Lang.current.separator)
    }
}

struct DetailSheet: View {
    let detail: RowDetail
    @Environment(\.dismiss) private var dismiss
    @State private var sub: RowDetail?

    private var r: PalaceRow { detail.row }

    var body: some View {
        ZStack {
            ZBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text(detail.title)
                            .font(Z.title(24))
                            .foregroundColor(Z.text)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.black)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Z.lime))
                        }
                        .accessibilityLabel(L("關閉", "Close", "Cerrar", "Chiudi"))
                    }

                    TVScreen(glow: r.reading.verdict.color) {
                        VStack(spacing: 12) {
                            Text("\(Words.palace(r.palace)) · \(Palace.name(r.palace))")
                                .font(Z.title(22))
                                .foregroundColor(Z.text)
                            ReadingTag(reading: r.reading, big: true)
                            Text(r.sentence)
                                .font(Z.body(17))
                                .foregroundColor(Z.text)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    topicCard("\(Words.effect) · \(Words.palace(r.reading.result))", r.reading.result, color: Z.lime)
                    if r.reading.cause != r.reading.result {
                        topicCard("\(Words.cause) · \(Words.palace(r.reading.cause))", r.reading.cause, color: Z.cyan)
                    }
                    topicCard(Words.palace(r.palace), r.palace, color: Z.pink)

                    ForEach(detail.sections.filter { !$0.items.isEmpty }) { sec in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(sec.title)
                                .font(Z.title(13))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Z.orange))
                            ForEach(sec.items) { it in
                                SimpleRow(label: it.label, row: it.row) {
                                    sub = RowDetail(title: "\(detail.title) · \(it.label)", row: it.row)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .sheet(item: $sub) { DetailSheet(detail: $0) }
        .preferredColorScheme(.dark)
    }

    private func topicCard(_ label: String, _ p: Int, color: Color) -> some View {
        ZCard(tag: label, tagColor: color, accent: color) {
            HStack(spacing: 12) {
                TopicBadge(palace: p)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(p) \(Palace.name(p))")
                        .font(Z.title(22))
                        .foregroundColor(Z.text)
                    Text(Topic.title(p))
                        .font(Z.body(13))
                        .foregroundColor(color)
                }
            }
            Text(Palace.text(p))
                .font(Z.body(13))
                .foregroundColor(Z.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 共用詞彙

enum Words {
    static var effect: String { L("果", "Effect", "Efecto", "Effetto") }
    static var cause: String { L("因", "Cause", "Causa", "Causa") }
    static var lifePalace: String { L("命宮", "Life Palace", "Palacio de Vida", "Palazzo della Vita") }
    static var luckPillar: String { L("大運", "Luck Pillar", "Pilar de Suerte", "Pilastro della Sorte") }
    static var annual: String { L("流年", "Annual", "Anual", "Annuale") }
    static var monthly: String { L("流月", "Monthly", "Mensual", "Mensile") }

    static func palace(_ p: Int) -> String {
        L("\(p)宮", "Palace \(p)", "Palacio \(p)", "Palazzo \(p)")
    }

    static func aspect(_ n: Int) -> String {
        L("第\(n)方面", "Aspect \(n)", "Aspecto \(n)", "Aspetto \(n)")
    }

    static func year(_ y: Int) -> String { L("\(String(y)) 年", String(y), String(y), String(y)) }

    static func month(_ m: Int) -> String { monthName(m, short: false) }
    static func monthShort(_ m: Int) -> String { monthName(m, short: true) }

    private static func monthName(_ m: Int, short: Bool) -> String {
        if Lang.current == .zh { return "\(m) 月" }
        let f = DateFormatter()
        f.locale = Lang.current.locale
        let names = (short ? f.shortStandaloneMonthSymbols : f.standaloneMonthSymbols) ?? []
        guard m >= 1, m <= names.count else { return "\(m)" }
        return names[m - 1].capitalized(with: Lang.current.locale)
    }

    static func yearMonth(_ y: Int, _ m: Int) -> String {
        L("\(String(y)) 年 \(m) 月", "\(month(m)) \(String(y))", "\(month(m)) de \(String(y))", "\(month(m)) \(String(y))")
    }

    static func shortDate(_ m: Int, _ d: Int) -> String {
        L("\(m)月\(d)日", "\(month(m)) \(d)", "\(d) de \(month(m))", "\(d) \(month(m))")
    }
}
