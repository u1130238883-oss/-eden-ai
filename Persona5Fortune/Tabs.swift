import SwiftUI

// MARK: - 今天

struct TodayTab: View {
    @EnvironmentObject private var store: Store
    @State private var detail: RowDetail?
    @State private var date = Date()
    @State private var showCalendar = false

    private var t: (year: Int, month: Int, day: Int) {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 2026, c.month ?? 1, c.day ?? 1)
    }

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let d = store.destiny {
                let t = self.t
                let f = d.dayFortune(month: t.month, day: t.day)
                let mo = d.month(t.month, year: t.year).row
                let yr = d.year(t.year)
                let luck = d.luckPeriod(containing: t.year)

                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        ZHeader(title: "\(greeting)\(L("，", ", ", ", ", ", "))\(store.displayName)",
                                subtitle: isToday ? "TODAY · \(t.month)/\(t.day)" : "DATE · \(String(t.year))/\(t.month)/\(t.day)")
                        calendarButton(t)
                    }

                    // 今日：日宮為主角
                    TVScreen {
                        VStack(spacing: 14) {
                            Text((isToday ? L("今天", "Today", "Hoy", "Oggi") : Words.shortDate(t.month, t.day)) + " · " + L("日宮", "Day palace", "Palacio del día", "Palazzo del giorno"))
                                .font(Z.mono(12))
                                .foregroundColor(Z.lime)
                            TopicBadge(palace: f.dayPalace, size: 76)
                            Text("\(f.dayPalace) \(Palace.name(f.dayPalace))")
                                .font(Z.title(38))
                                .foregroundColor(Z.text)
                            Text(Topic.title(f.dayPalace))
                                .font(Z.title(15))
                                .foregroundColor(Z.lime)
                            Text(L("容易碰到：", "Likely to meet: ", "Es probable encontrar: ", "Probabile incontrare: ") + Topic.hint(f.dayPalace))
                                .font(Z.body(15))
                                .foregroundColor(Z.dim)
                                .multilineTextAlignment(.center)
                        }
                    }

                    ZCard(tag: L("晚上・夜宮", "Night palace", "Palacio de la noche", "Palazzo della notte"), tagColor: Z.cyan, accent: Z.cyan) {
                        HStack(spacing: 12) {
                            TopicBadge(palace: f.nightPalace, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(f.nightPalace) \(Palace.name(f.nightPalace)) · \(Topic.title(f.nightPalace))")
                                    .font(Z.title(18))
                                    .foregroundColor(Z.text)
                                Text(Topic.hint(f.nightPalace))
                                    .font(Z.body(13))
                                    .foregroundColor(Z.dim)
                            }
                        }
                    }

                    summaryCard(Words.monthly, Words.yearMonth(t.year, t.month), mo, Z.lime) {
                        detail = RowDetail(title: "\(Words.yearMonth(t.year, t.month)) · \(Words.monthly)", row: mo)
                    }
                    let ySec = Triggers.year(d, t.year)
                    summaryCard(Words.annual, Words.year(t.year), yr, Z.orange) {
                        detail = RowDetail(title: "\(Words.year(t.year)) · \(Words.annual)", row: yr, sections: ySec)
                    }
                    let lSec = Triggers.luck(d, luck)
                    summaryCard(Words.luckPillar, luck.span, luck.row, Z.pink) {
                        detail = RowDetail(title: "\(luck.span) · \(Words.luckPillar)", row: luck.row, sections: lSec)
                    }
                }
                .padding(20)
            }
        }
        .sheet(item: $detail) { DetailSheet(detail: $0) }
        .sheet(isPresented: $showCalendar) { calendarSheet }
    }

    private func calendarButton(_ t: (year: Int, month: Int, day: Int)) -> some View {
        Button {
            Z.haptic(.light)
            showCalendar = true
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "calendar")
                    .font(.system(size: 22, weight: .black))
                Text("\(t.month)/\(t.day)")
                    .font(Z.title(13))
            }
            .foregroundColor(.black)
            .frame(width: 64, height: 64)
            .background(RoundedRectangle(cornerRadius: 16).fill(Z.lime))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 3))
        }
        .padding(.top, 14)
        .accessibilityLabel(L("選擇日期", "Choose date", "Elegir fecha", "Scegli data"))
    }

    private var calendarSheet: some View {
        ZStack {
            ZBackground()
            VStack(spacing: 18) {
                Text(L("選擇日期", "Choose date", "Elegir fecha", "Scegli data"))
                    .font(Z.title(24))
                    .foregroundColor(Z.text)
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .tint(Z.lime)
                    .environment(\.locale, Lang.current.locale)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Z.panel))
                HStack(spacing: 12) {
                    Button(L("回到今天", "Today", "Hoy", "Oggi")) {
                        date = Date()
                        showCalendar = false
                    }
                    .buttonStyle(ZButtonStyle(color: Z.cyan))
                    Button(L("完成", "Done", "Listo", "Fatto")) { showCalendar = false }
                        .buttonStyle(ZButtonStyle())
                }
                Spacer()
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return L("早安", "Good morning", "Buenos días", "Buongiorno")
        case 12..<18: return L("午安", "Good afternoon", "Buenas tardes", "Buon pomeriggio")
        default: return L("晚安", "Good evening", "Buenas noches", "Buonasera")
        }
    }

    private func summaryCard(_ tag: String, _ when: String, _ row: PalaceRow, _ color: Color, tap: @escaping () -> Void) -> some View {
        Button {
            Z.haptic(.light)
            tap()
        } label: {
            ZCard(tag: tag, tagColor: color, accent: color) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(when)
                            .font(Z.mono(12))
                            .foregroundColor(Z.dim)
                        Text("\(Words.palace(row.palace)) · \(Palace.name(row.palace))")
                            .font(Z.title(20))
                            .foregroundColor(Z.text)
                    }
                    Spacer()
                    ReadingTag(reading: row.reading, big: true)
                }
                CauseLine(reading: row.reading)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 運勢

struct LuckTab: View {
    @EnvironmentObject private var store: Store
    @State private var mode = 0
    @State private var year = Today.components.year
    @State private var annualStart = Today.components.year
    @State private var detail: RowDetail?

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let d = store.destiny {
                VStack(alignment: .leading, spacing: 18) {
                    ZHeader(title: L("運勢", "Luck", "Suerte", "Sorte"), subtitle: "\(Words.monthly) · \(Words.annual) · \(Words.luckPillar)")
                    ZSegments(items: [(0, Words.monthly), (1, Words.annual), (2, Words.luckPillar)], selection: $mode)

                    switch mode {
                    case 0: months(d)
                    case 1: years(d)
                    default: decades(d)
                    }
                }
                .padding(20)
            }
        }
        .sheet(item: $detail) { DetailSheet(detail: $0) }
    }

    @ViewBuilder
    private func months(_ d: Destiny) -> some View {
        YearSwitcher(year: $year)
        let now = Today.components
        ForEach(d.monthChart(year: year)) { m in
            SimpleRow(label: Words.monthShort(m.month), row: m.row, palace: m.row.palace,
                      highlight: year == now.year && m.month == now.month) {
                detail = RowDetail(title: "\(Words.yearMonth(year, m.month)) · \(Words.monthly)", row: m.row)
            }
        }
    }

    @ViewBuilder
    private func years(_ d: Destiny) -> some View {
        let now = Today.components.year
        YearSwitcher(year: $annualStart)
        ForEach(0..<12, id: \.self) { i in
            let y = annualStart + i
            let r = d.year(y)
            let sec = Triggers.year(d, y)
            SimpleRow(label: String(y), row: r, palace: r.palace, highlight: y == now) {
                detail = RowDetail(title: "\(Words.year(y)) · \(Words.annual)", row: r, sections: sec)
            }
        }
    }

    @ViewBuilder
    private func decades(_ d: Destiny) -> some View {
        let now = Today.components.year
        ForEach(d.luckPeriods(count: 10)) { p in
            let sec = Triggers.luck(d, p)
            SimpleRow(label: p.span, row: p.row, palace: p.row.palace, highlight: p.contains(now)) {
                detail = RowDetail(title: "\(p.span) · \(Words.luckPillar)", row: p.row, sections: sec)
            }
        }
    }
}

// MARK: - 命盤

struct ChartTab: View {
    @EnvironmentObject private var store: Store
    @State private var detail: RowDetail?
    @State private var showMore = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let d = store.destiny {
                let type = Enneagram.type(forLifeNumber: d.lifeNumber)
                let good = d.natalChart.filter { $0.reading.verdict == .good }.count
                let bad = d.natalChart.filter { $0.reading.verdict == .bad }.count

                VStack(alignment: .leading, spacing: 18) {
                    ZHeader(title: L("我的命盤", "My chart", "Mi carta", "La mia carta"), subtitle: "NATAL CHART")

                    TVScreen(glow: Z.orange) {
                        VStack(spacing: 10) {
                            Text(L("你的性格", "Your type", "Tu tipo", "Il tuo tipo"))
                                .font(Z.mono(12))
                                .foregroundColor(Z.orange)
                            Text(Enneagram.name(type))
                                .font(Z.title(32))
                                .foregroundColor(Z.text)
                            Text(Enneagram.tagline(type))
                                .font(Z.body(15))
                                .foregroundColor(Z.lime)
                                .multilineTextAlignment(.center)
                        }
                    }

                    ZCard(tag: L("性格說明", "About your type", "Sobre tu tipo", "Il tuo tipo"), tagColor: Z.orange, accent: Z.orange) {
                        Text(Enneagram.summary(type))
                            .font(Z.body(14))
                            .foregroundColor(Z.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            withAnimation { showMore.toggle() }
                        } label: {
                            Text(showMore ? L("收起 ▲", "Less ▲", "Menos ▲", "Meno ▲") : L("看完整性格分析 ▼", "Full analysis ▼", "Análisis completo ▼", "Analisi completa ▼"))
                                .font(Z.title(13))
                                .foregroundColor(Z.orange)
                        }
                        if showMore {
                            let sections = Enneagram.sections(type)
                            ForEach(0..<sections.count, id: \.self) { i in
                                Text(Enneagram.sectionTitles[i])
                                    .font(Z.title(15))
                                    .foregroundColor(Z.lime)
                                    .padding(.top, 6)
                                ForEach(0..<sections[i].count, id: \.self) { j in
                                    Text("• \(sections[i][j])")
                                        .font(Z.body(13))
                                        .foregroundColor(Z.dim)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("本命十二宮", "The twelve palaces", "Los doce palacios", "I dodici palazzi"))
                            .font(Z.title(20))
                            .foregroundColor(Z.text)
                        Text("\(Verdict.good.name) \(good) · \(Verdict.neutral.name) \(12 - good - bad) · \(Verdict.bad.name) \(bad)")
                            .font(Z.body(13))
                            .foregroundColor(Z.dim)
                    }

                    ForEach(d.natalChart) { r in
                        SimpleRow(label: "\(r.palace) \(Palace.name(r.palace))", row: r,
                                  highlight: r.index == 0) {
                            detail = RowDetail(title: "\(Words.palace(r.palace)) · \(Palace.name(r.palace))", row: r, sections: Triggers.natal(d, r))
                        }
                    }
                }
                .padding(20)
            }
        }
        .sheet(item: $detail) { DetailSheet(detail: $0) }
    }
}

// MARK: - 合盤

struct MatchTab: View {
    @EnvironmentObject private var store: Store
    @State private var name = ""
    @State private var birth = Date(timeIntervalSince1970: 946_684_800)
    @State private var current: Person?
    @State private var detail: RowDetail?
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let me = store.destiny {
                VStack(alignment: .leading, spacing: 18) {
                    ZHeader(title: L("合盤", "Synastry", "Sinastría", "Sinastria"), subtitle: "SYNASTRY")

                    if let p = current {
                        result(me, p)
                        Button(L("換一個人合盤", "Someone else", "Otra persona", "Un'altra persona")) {
                            withAnimation { current = nil }
                        }
                        .buttonStyle(ZButtonStyle(color: Z.cyan))
                    } else {
                        form
                    }

                    if !store.others.isEmpty && current == nil {
                        ZCard(tag: L("最近合盤", "Recently combined", "Combinados recientemente", "Combinati di recente"), tagColor: Z.cyan, accent: Z.cyan) {
                            ForEach(store.others) { p in
                                Button {
                                    Z.haptic(.light)
                                    withAnimation { current = p }
                                } label: {
                                    HStack {
                                        Image(systemName: "person.fill")
                                        Text(p.name)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .font(Z.title(16))
                                    .foregroundColor(Z.text)
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .sheet(item: $detail) { DetailSheet(detail: $0) }
    }

    private var form: some View {
        VStack(spacing: 18) {
            ZCard(tag: L("對方的名字", "Their name", "Su nombre", "Il suo nome"), tagColor: Z.lime, accent: Z.lime) {
                TextField("", text: $name)
                    .font(Z.title(20))
                    .foregroundColor(.black)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { focused = false }
            }
            ZCard(tag: L("對方的生日", "Their birthday", "Su fecha de nacimiento", "La sua data di nascita"), tagColor: Z.lime, accent: Z.lime) {
                BirthPicker(date: $birth)
            }
            Button {
                focused = false
                let n = name.trimmingCharacters(in: .whitespaces)
                let p = Person(name: n.isEmpty ? L("對方", "Them", "Otra persona", "L'altra persona") : n, birth: BirthDate(from: birth))
                store.addOther(p)
                Z.success()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { current = p }
                name = ""
            } label: {
                Text(L("開始合盤  ▶", "Combine  ▶", "Combinar  ▶", "Combina  ▶"))
            }
            .buttonStyle(ZButtonStyle(color: Z.lime))
        }
    }

    @ViewBuilder
    private func result(_ me: Destiny, _ p: Person) -> some View {
        let other = Destiny(birth: p.birth, anchor: store.anchor)
        let s = me.synastry(with: other)
        let combined = Num.r9(me.lifeNumber + other.lifeNumber)
        SynastryBar(names: "\(store.displayName) × \(p.name)",
                    number: combined,
                    numberLabel: L("合盤靈數", "SYNC NO.", "Nº VIDA", "Nº VITA"))

        ForEach(s.chart) { r in
            SimpleRow(label: "\(r.palace) \(Palace.name(r.palace))", row: r,
                      highlight: r.index == 0) {
                detail = RowDetail(title: "\(L("合盤", "Synastry", "Sinastría", "Sinastria")) · \(Words.palace(r.palace)) · \(Palace.name(r.palace))", row: r)
            }
        }
    }
}

// MARK: - 我

struct MeTab: View {
    @EnvironmentObject private var store: Store
    @State private var name = ""
    @State private var birth = Date()
    @State private var query = ""
    @State private var saved = false
    @State private var confirmReset = false
    @State private var showAdvanced = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                ZHeader(title: L("我的資料", "My profile", "Mi perfil", "Il mio profilo"), subtitle: "PROXY PROFILE")

                ZCard(tag: L("語言", "Language", "Idioma", "Lingua"), tagColor: Z.cyan, accent: Z.cyan) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(Lang.allCases, id: \.self) { l in
                            Button {
                                Z.haptic(.light)
                                store.lang = l
                            } label: {
                                Text(l.title)
                                    .font(Z.title(16))
                                    .foregroundColor(store.lang == l ? .black : Z.text)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(store.lang == l ? Z.lime : Z.panel2))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 2))
                            }
                        }
                    }
                }

                ZCard(tag: L("名字", "Name", "Nombre", "Nome")) {
                    TextField("", text: $name)
                        .font(Z.title(20))
                        .foregroundColor(.black)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                }
                ZCard(tag: L("生日", "Birthday", "Fecha de nacimiento", "Data di nascita"), tagColor: Z.orange, accent: Z.orange) {
                    BirthPicker(date: $birth)
                }
                Button {
                    let n = name.trimmingCharacters(in: .whitespaces)
                    store.owner = Person(id: store.owner?.id ?? UUID(), name: n.isEmpty ? L("你", "You", "Tú", "Tu") : n,
                                         birth: BirthDate(from: birth))
                    Z.success()
                    withAnimation { saved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { saved = false } }
                } label: {
                    Text(saved ? L("已儲存 ✓", "Saved ✓", "Guardado ✓", "Salvato ✓") : L("儲存", "Save", "Guardar", "Salva"))
                }
                .buttonStyle(ZButtonStyle())

                dictionary

                Button {
                    withAnimation { showAdvanced.toggle() }
                } label: {
                    Text(L("進階設定", "Advanced", "Avanzado", "Avanzate") + (showAdvanced ? " ▲" : " ▼"))
                        .font(Z.title(14))
                        .foregroundColor(Z.dim)
                }
                if showAdvanced {
                    ZCard(tag: L("年錨", "Year anchor", "Anclaje anual", "Ancoraggio annuale"), accent: Z.panel2) {
                        ForEach(YearAnchor.allCases, id: \.self) { a in
                            Button {
                                Z.haptic(.light)
                                store.anchor = a
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: store.anchor == a ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(Z.lime)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(a.title).font(Z.title(15)).foregroundColor(Z.text)
                                        Text(a.detail).font(Z.body(12)).foregroundColor(Z.dim)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button(L("清除全部資料", "Clear all data", "Borrar todos los datos", "Cancella tutti i dati")) { confirmReset = true }
                        .buttonStyle(ZButtonStyle(color: Z.orange))
                }

                Text(L("算法：九型十二宮（Nine & Twelve）。僅供娛樂參考。", "Method: Nine & Twelve. For entertainment only.",
                       "Método: Nueve y Doce. Solo para entretenimiento.", "Metodo: Nove e Dodici. Solo per intrattenimento."))
                    .font(Z.body(11))
                    .foregroundColor(Z.dim)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
        .alert(L("清除全部資料？", "Clear all data?", "¿Borrar todos los datos?", "Cancellare tutti i dati?"), isPresented: $confirmReset) {
            Button(L("清除", "Clear", "Borrar", "Cancella"), role: .destructive) { store.reset() }
            Button(L("取消", "Cancel", "Cancelar", "Annulla"), role: .cancel) {}
        } message: {
            Text(L("你的資料與合盤紀錄都會被刪除，無法復原。", "Your birth details and synastry history will be deleted. This cannot be undone.",
                   "Se borrarán tus datos de nacimiento y el historial de sinastría. No se puede deshacer.",
                   "I tuoi dati di nascita e la cronologia della sinastria verranno eliminati. Non si può annullare."))
        }
        .onAppear {
            name = store.owner?.name ?? ""
            birth = store.owner?.birth.date ?? Date()
        }
    }

    private var dictionary: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        let list = (1...12).filter { p in
            q.isEmpty || Topic.title(p).contains(q) || Palace.keywords(p).contains { $0.contains(q) }
        }
        return ZCard(tag: L("十二宮含義", "Meanings of the twelve palaces", "Significados de los doce palacios", "Significati dei dodici palazzi"), tagColor: Z.cyan, accent: Z.cyan) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.black)
                TextField("", text: $query, prompt: Text(L("搜尋含義", "Search meanings", "Buscar significados", "Cerca significati")).foregroundColor(.gray))
                    .font(Z.body(15))
                    .foregroundColor(.black)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))

            ForEach(list, id: \.self) { p in
                HStack(alignment: .top, spacing: 10) {
                    TopicBadge(palace: p, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Topic.title(p)).font(Z.title(15)).foregroundColor(Z.text)
                        Text(Palace.text(p)).font(Z.body(12)).foregroundColor(Z.dim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }
            if list.isEmpty {
                Text(L("找不到「\(q)」", "No match for “\(q)”", "Sin resultados para «\(q)»", "Nessun risultato per «\(q)»")).font(Z.body(13)).foregroundColor(Z.dim)
            }
        }
    }
}
