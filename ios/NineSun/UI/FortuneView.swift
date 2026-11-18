import EchoCore
import SwiftUI

/// 命盤：九型十二宮的完整命理（今日、本命、性格、大運、合盤）。資料只在這台手機，不會上傳。
struct FortuneView: View {
    @EnvironmentObject var vm: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    enum Tab: Int, CaseIterable { case today, natal, persona, luck, match }
    @State private var tab: Tab = .today
    @State private var year = Calendar(identifier: .gregorian).component(.year, from: Date())
    @State private var open: Set<Int> = []
    @State private var showAllPersona = false
    // 還沒設定生日
    @State private var newBirth = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
    // 合盤的對方
    @State private var otherName = ""
    @State private var otherBirth = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
    @State private var match: BirthDay?
    /// 名字合盤：輸入的名字（英文字母）
    @State private var nameMatch: String?

    private var L: Lang { vm.language }

    var body: some View {
        ZStack {
            HalftoneBackground()
                .onTapGesture { hideKeyboard() }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        GlitchText(text: T("命盤", "CHART", "CARTA", "TEMA"), size: 30)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 16, weight: .black))
                                .foregroundColor(Theme.ink).frame(width: 40, height: 32)
                                .background(Slanted(skew: 6).fill(Theme.hazard))
                        }
                    }
                    HazardStripes(height: 6)
                    if let b = vm.profile.birthday {
                        let D = Destiny(b)
                        header(D)
                        tabBar
                        switch tab {
                        case .today: today(D)
                        case .natal: natal(D)
                        case .persona: persona(D)
                        case .luck: luck(D)
                        case .match: matchTab(D)
                        }
                    } else {
                        setup
                    }
                    Text(T("資料只存在這台手機，不會上傳。命理內容僅供娛樂與自我覺察參考。", "Your data stays on this phone. Readings are for fun and self-reflection.",
                           "Tus datos se quedan en este teléfono. Las lecturas son para entretenimiento.", "I dati restano sul telefono. Le letture sono per intrattenimento."))
                        .font(Theme.hud(10)).foregroundColor(Theme.dim)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 沒有生日

    private var setup: some View {
        section(T("先輸入生日", "Your birthday", "Tu cumpleaños", "Il tuo compleanno") + " · SETUP") {
            DatePicker(T("生日", "Birthday", "Cumpleaños", "Compleanno"), selection: $newBirth, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "zh_Hant_TW"))
                .foregroundColor(Theme.paper)
            button(T("看我的命盤 ▶", "Show my chart ▶", "Ver mi carta ▶", "Vedi il mio tema ▶")) {
                let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: newBirth)
                var p = vm.profile
                p.birthday = BirthDay(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
                vm.profile = p
            }
        }
    }

    // MARK: - 頂部：命主

    private func header(_ D: Destiny) -> some View {
        let natal = D.natal[0]
        return section(T("命主", "You", "Tú", "Tu") + " · PROFILE") {
            HStack(alignment: .firstTextBaseline) {
                // 不顯示生日（使用者要求），大標題用九型的名字
                Text(typeName(D.type)).font(Theme.display(22)).foregroundColor(Theme.paper)
                Spacer()
                Text(T("第\(D.type)型", "Type \(D.type)", "Tipo \(D.type)", "Tipo \(D.type)")).font(Theme.hud(13)).foregroundColor(Theme.ink)
                    .padding(.horizontal, 10).padding(.vertical, 4).background(Slanted(skew: 5).fill(Theme.hazard))
            }
            Text(tagline(D.type)).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.hazard)
            Text(T("命宮", "Life palace", "Palacio de vida", "Palazzo della vita") + "：" + label(natal.palace) + "　" + keywords(natal.palace))
                .font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.paper)
            verdictLine(natal.reading)
        }
    }

    private var tabBar: some View {
        let names = [T("今日", "Today", "Hoy", "Oggi"), T("本命", "Natal", "Natal", "Natale"), T("性格", "Persona", "Persona", "Persona"),
                     T("大運", "Luck", "Suerte", "Fortuna"), T("合盤", "Match", "Pareja", "Coppia")]
        return HStack(spacing: 6) {
            ForEach(Tab.allCases, id: \.rawValue) { t in
                Button { withAnimation(.easeOut(duration: 0.15)) { tab = t; open = [] } } label: {
                    Text(names[t.rawValue]).font(.system(size: 14, weight: .black))
                        .foregroundColor(tab == t ? Theme.ink : Theme.paper)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(Slanted(skew: 6).fill(tab == t ? Theme.hazard : Theme.panelHi))
                }
            }
        }
    }

    // MARK: - 今日

    private func today(_ D: Destiny) -> some View {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let y = cal.component(.year, from: now), m = cal.component(.month, from: now), d = cal.component(.day, from: now)
        let dn = D.day(month: m, day: d)
        let yr = D.year(y), mo = D.month(m, year: y)
        return VStack(alignment: .leading, spacing: 18) {
            section(T("今天", "Today", "Hoy", "Oggi") + " · \(m)/\(d)") {
                palaceLine(T("白天", "Day", "Día", "Giorno"), dn.day)
                palaceLine(T("晚上", "Night", "Noche", "Notte"), dn.night)
            }
            section(T("這個月", "This month", "Este mes", "Questo mese") + " · \(m)" + T("月", "", "", "")) {
                rowView(mo, title: T("流月", "Month", "Mes", "Mese"))
            }
            section(T("今年", "This year", "Este año", "Quest'anno") + " · \(y)") {
                rowView(yr, title: T("流年", "Year", "Año", "Anno"))
            }
        }
    }

    // MARK: - 本命

    private func natal(_ D: Destiny) -> some View {
        section(T("本命十二宮", "Natal palaces", "Palacios natales", "Palazzi natali") + " · NATAL") {
            Text(T("點一宮看它會引動哪些宮。", "Tap a palace to see which palaces it sets off.", "Toca un palacio para ver qué activa.", "Tocca un palazzo per vedere cosa attiva."))
                .font(.system(size: 11, weight: .medium)).foregroundColor(Theme.dim)
            ForEach(1...12, id: \.self) { p in
                if let r = D.natal.first(where: { $0.palace == p }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Button { toggle(p) } label: { rowView(r, title: nil, chevron: open.contains(p) ? "▲" : "▼") }
                            .buttonStyle(.plain)
                        if open.contains(p) {
                            let hits = D.triggeredByNatal(p)
                            Text(T("本命 \(p) 宮引動的本命宮：", "Palace \(p) sets off:", "El palacio \(p) activa:", "Il palazzo \(p) attiva:"))
                                .font(Theme.hud(11)).foregroundColor(Theme.signal)
                            if hits.isEmpty {
                                Text(T("沒有引動其他宮。", "None.", "Ninguno.", "Nessuno.")).font(.system(size: 12)).foregroundColor(Theme.dim)
                            }
                            ForEach(hits, id: \.self) { h in rowView(h, title: nil, compact: true) }
                        }
                    }
                    if p < 12 { Divider().background(Theme.panelHi) }
                }
            }
        }
    }

    // MARK: - 性格

    private func persona(_ D: Destiny) -> some View {
        let prof = vm.i18n?.typeProfile(D.type, L) ?? (summary: "", titles: [], sections: [])
        return section(T("九型人格", "Enneagram", "Eneagrama", "Enneagramma") + " · PERSONA") {
            Text(T("第\(D.type)型「\(typeName(D.type))」", "Type \(D.type) · \(typeName(D.type))", "Tipo \(D.type) · \(typeName(D.type))", "Tipo \(D.type) · \(typeName(D.type))"))
                .font(Theme.display(20)).foregroundColor(Theme.hazard)
            Text(tagline(D.type)).font(.system(size: 13, weight: .bold)).foregroundColor(Theme.paper)
            if !prof.summary.isEmpty {
                Text(prof.summary).font(.system(size: 14, weight: .medium)).foregroundColor(Theme.paper).lineSpacing(4)
            }
            if !prof.sections.isEmpty {
                Button { withAnimation(.easeOut(duration: 0.2)) { showAllPersona.toggle() } } label: {
                    Text(showAllPersona ? T("收起 ▲", "Hide ▲", "Ocultar ▲", "Nascondi ▲") : T("看完整性格分析 ▼", "Full analysis ▼", "Análisis completo ▼", "Analisi completa ▼"))
                        .font(.system(size: 14, weight: .black)).foregroundColor(Theme.ink)
                        .padding(.horizontal, 18).padding(.vertical, 8).background(Slanted(skew: 7).fill(Theme.hazard))
                }
                if showAllPersona {
                    ForEach(Array(prof.sections.enumerated()), id: \.offset) { i, items in
                        VStack(alignment: .leading, spacing: 6) {
                            TagLabel(text: i < prof.titles.count ? prof.titles[i] : "")
                            ForEach(Array(items.enumerated()), id: \.offset) { _, line in
                                Text("• " + line).font(.system(size: 13, weight: .medium)).foregroundColor(Theme.paper).lineSpacing(3)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    // MARK: - 大運

    private func luck(_ D: Destiny) -> some View {
        let lp = D.luckPeriod(year)
        return VStack(alignment: .leading, spacing: 18) {
            section(T("年份", "Year", "Año", "Anno") + " · YEAR") {
                HStack {
                    button("◀", color: Theme.panelHi) { year -= 1 }
                    Spacer()
                    Text("\(year)").font(Theme.display(24)).foregroundColor(Theme.paper)
                    Spacer()
                    button("▶", color: Theme.panelHi) { year += 1 }
                }
            }
            section(T("大運", "Luck period", "Periodo", "Periodo") + " · \(lp.start)–\(lp.end)") {
                rowView(lp.row, title: T("這十年", "This decade", "Esta década", "Questo decennio"))
            }
            section(T("流年", "Year", "Año", "Anno") + " · \(year)") {
                rowView(D.year(year), title: T("這一年", "This year", "Este año", "Quest'anno"))
                let ta = D.triggeredAspects(year)
                if !ta.isEmpty {
                    Text(T("流年引動的大運方面", "Luck aspects this year sets off", "Aspectos activados", "Aspetti attivati")).font(Theme.hud(11)).foregroundColor(Theme.signal)
                    ForEach(ta, id: \.self) { r in rowView(r, title: nil, compact: true, aspect: true) }
                }
                let tn = D.triggeredNatal(year)
                if !tn.isEmpty {
                    Text(T("大運引動的本命宮", "Natal palaces the decade sets off", "Palacios natales activados", "Palazzi natali attivati")).font(Theme.hud(11)).foregroundColor(Theme.signal)
                    ForEach(tn, id: \.self) { r in rowView(r, title: nil, compact: true) }
                }
            }
            section(T("這一段大運的十二個方面", "The twelve aspects of this decade", "Los doce aspectos", "I dodici aspetti") + " · ASPECTS") {
                ForEach(D.luckAspects(year), id: \.self) { r in
                    rowView(r, title: nil, aspect: true)
                    if r.palace < 12 { Divider().background(Theme.panelHi) }
                }
            }
        }
    }

    // MARK: - 合盤

    private func matchTab(_ D: Destiny) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if let n = nameMatch {
                nameSection(D, name: n)
            } else if let o = match {
                section(T("合盤", "Match", "Pareja", "Coppia") + " · \(otherName.isEmpty ? o.display : otherName)") {
                    Text(T("你（第\(D.type)型）× 對方（第\(Destiny(o).type)型「\(typeName(Destiny(o).type))」）",
                           "You (type \(D.type)) × them (type \(Destiny(o).type))", "Tú (tipo \(D.type)) × la otra persona (tipo \(Destiny(o).type))",
                           "Tu (tipo \(D.type)) × l'altra persona (tipo \(Destiny(o).type))"))
                        .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.hazard)
                    let rows = D.synastry(with: Destiny(o))
                    ForEach(1...12, id: \.self) { p in
                        if let r = rows.first(where: { $0.palace == p }) {
                            rowView(r, title: nil)
                            if p < 12 { Divider().background(Theme.panelHi) }
                        }
                    }
                    button(T("換一個人合盤", "Another person", "Otra persona", "Un'altra persona"), color: Theme.panelHi) { match = nil }
                }
            } else {
                section(T("和誰合盤？", "Match with whom?", "¿Con quién?", "Con chi?") + " · MATCH") {
                    TextField(T("對方的名字（可以不填）", "Their name (optional)", "Su nombre (opcional)", "Il suo nome (facoltativo)"), text: $otherName)
                        .font(.system(size: 14, weight: .medium)).foregroundColor(Theme.paper)
                        .padding(10).background(Theme.panelHi)
                    DatePicker(T("對方生日", "Their birthday", "Su cumpleaños", "Il suo compleanno"), selection: $otherBirth, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_Hant_TW"))
                        .foregroundColor(Theme.paper)
                    HStack(spacing: 10) {
                        button(T("生日合盤 ▶", "By birthday ▶", "Por fecha ▶", "Per data ▶")) {
                            hideKeyboard()
                            let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: otherBirth)
                            nameMatch = nil
                            match = BirthDay(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
                        }
                        button(T("名字合盤 ▶", "By name ▶", "Por nombre ▶", "Per nome ▶"), color: Theme.signal) {
                            hideKeyboard()
                            match = nil
                            open = []
                            nameMatch = otherName.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    Text(T("名字合盤用英文字母（例如 china、Kevin），不用填生日；生日合盤不用填名字。",
                           "Name match uses English letters and needs no birthday; birthday match needs no name.",
                           "La de nombre usa letras inglesas y no necesita fecha; la de fecha no necesita nombre.",
                           "Quella per nome usa lettere inglesi e non serve la data; quella per data non serve il nome."))
                        .font(.system(size: 11, weight: .medium)).foregroundColor(Theme.dim)
                }
            }
        }
    }

    /// 名字合盤：名字裡每個英文字母（a=1…z=26）加上自己的靈數，對到本命的一宮，依序列出；點開看它引動哪些宮
    private func nameSection(_ D: Destiny, name: String) -> some View {
        // 和 nameRows 用一樣的規則挑字母，才一一對得上
        let letters = name.lowercased().unicodeScalars.filter { $0.value >= 97 && $0.value <= 122 }.map { String(Character($0)).uppercased() }
        let rows = D.nameRows(name)
        return section(T("名字合盤", "Name match", "Por nombre", "Per nome") + " · " + (name.isEmpty ? "—" : name)) {
            if rows.isEmpty {
                Text(T("請輸入英文字母。", "Please enter English letters.", "Introduce letras del alfabeto inglés.", "Inserisci lettere dell'alfabeto inglese."))
                    .font(.system(size: 13, weight: .medium)).foregroundColor(Theme.paper)
            } else {
                Text(T("每個字母對到你本命的一宮，點一列看它引動哪些宮。", "Each letter lands on one of your natal palaces; tap to see what it sets off.",
                       "Cada letra cae en uno de tus palacios; toca para ver qué activa.", "Ogni lettera cade su un tuo palazzo; tocca per vedere cosa attiva."))
                    .font(.system(size: 11, weight: .medium)).foregroundColor(Theme.dim)
                ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                    VStack(alignment: .leading, spacing: 6) {
                        Button { toggle(100 + i) } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text(i < letters.count ? letters[i] : "").font(Theme.display(20)).foregroundColor(Theme.signal).frame(width: 24)
                                rowView(r, title: nil, chevron: open.contains(100 + i) ? "▲" : "▼", compact: true)
                            }
                        }
                        .buttonStyle(.plain)
                        if open.contains(100 + i) {
                            let hits = D.triggeredByNatal(r.palace)
                            if hits.isEmpty {
                                Text(T("沒有引動其他宮。", "None.", "Ninguno.", "Nessuno.")).font(.system(size: 12)).foregroundColor(Theme.dim)
                            }
                            ForEach(hits, id: \.self) { h in rowView(h, title: nil, compact: true) }
                        }
                    }
                    if i < rows.count - 1 { Divider().background(Theme.panelHi) }
                }
            }
            button(T("換一個名字", "Another name", "Otro nombre", "Un altro nome"), color: Theme.panelHi) { nameMatch = nil }
        }
    }

    // MARK: - 一列（宮位、好壞、果、因）

    @ViewBuilder
    private func rowView(_ r: NTRow, title: String?, chevron: String? = nil, compact: Bool = false, aspect: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let title { Text(title).font(Theme.hud(11)).foregroundColor(Theme.dim) }
                Text((aspect ? T("方面", "Aspect ", "Aspecto ", "Aspetto ") : "") + label(r.palace))
                    .font(.system(size: compact ? 13 : 15, weight: .black)).foregroundColor(Theme.paper)
                Spacer()
                verdictChip(r.reading.verdict)
                if let chevron { Text(chevron).font(Theme.hud(11)).foregroundColor(Theme.dim) }
            }
            if !compact {
                Text(keywords(r.palace)).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.dim)
            }
            Text(T("果：", "Result: ", "Efecto: ", "Effetto: ") + label(r.reading.result) + "　" + T("因：", "Cause: ", "Causa: ", "Causa: ") + label(r.reading.cause))
                .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.paper.opacity(0.85))
        }
        .contentShape(Rectangle())
    }

    private func palaceLine(_ title: String, _ p: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(Theme.hud(11)).foregroundColor(Theme.dim)
                Text(label(p)).font(.system(size: 15, weight: .black)).foregroundColor(Theme.paper)
            }
            Text(keywords(p)).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.dim)
        }
    }

    private func verdictLine(_ r: NTReading) -> some View {
        HStack(spacing: 8) {
            verdictChip(r.verdict)
            Text(T("果：", "Result: ", "Efecto: ", "Effetto: ") + label(r.result) + "　" + T("因：", "Cause: ", "Causa: ", "Causa: ") + label(r.cause))
                .font(.system(size: 12, weight: .semibold)).foregroundColor(Theme.paper)
        }
    }

    private func verdictChip(_ v: NTVerdict) -> some View {
        let name = [T("好", "Good", "Bien", "Bene"), T("正", "Even", "Neutro", "Neutro"), T("壞", "Rough", "Difícil", "Difficile")][v.rawValue]
        let color = [Theme.hazard, Theme.signal, Theme.neonPink][v.rawValue]
        return Text(name).font(.system(size: 12, weight: .black)).foregroundColor(Theme.ink)
            .padding(.horizontal, 8).padding(.vertical, 2).background(Slanted(skew: 4).fill(color))
    }

    // MARK: - 名稱

    /// 十二宮在生活裡的方面
    static let areas = ["自己・情緒", "錢財・物質", "溝通・學習", "家庭・安全感", "戀愛・桃花", "忙碌・日常",
                        "伴侶・人際", "偏財・身體", "好運・遠行", "事業・地位", "朋友・變動", "內心・隱藏"]

    private func label(_ p: Int) -> String {
        let q = NT.r12(p)
        if L == .zh { return "\(q)宮「\(NT.palaceName(q))」\(Self.areas[q - 1])" }
        return vm.i18n?.pn(q, L) ?? "\(q)"
    }

    private func keywords(_ p: Int) -> String {
        let q = NT.r12(p)
        if L == .zh { return NT.keywords(q, 6) }
        return vm.i18n?.kw(q, 6, L) ?? ""
    }

    private func typeName(_ t: Int) -> String { L == .zh ? NT.typeName(t) : (vm.i18n?.typeName(t, L) ?? NT.typeName(t)) }
    private func tagline(_ t: Int) -> String { L == .zh ? NT.typeTagline(t) : (vm.i18n?.tagline(t, L) ?? NT.typeTagline(t)) }

    private func toggle(_ p: Int) {
        withAnimation(.easeOut(duration: 0.15)) { if open.contains(p) { open.remove(p) } else { open.insert(p) } }
    }

    // MARK: - 元件（和調頻台一樣）

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TagLabel(text: title)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NotchedPanel(cut: 14).fill(Theme.panel.opacity(0.95)))
    }

    private func button(_ t: String, color: Color = Theme.hazard, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 14, weight: .black))
                .foregroundColor(color == Theme.panelHi ? Theme.paper : Theme.ink)
                .padding(.horizontal, 18).padding(.vertical, 8)
                .background(Slanted(skew: 7).fill(color))
        }
    }
}
