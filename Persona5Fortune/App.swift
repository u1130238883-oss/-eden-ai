import SwiftUI

@main
struct HollowFortuneApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

enum AppTab: Int, CaseIterable {
    case today, luck, chart, match, me

    var title: String {
        switch self {
        case .today: return L("今天", "Today", "Hoy", "Oggi")
        case .luck: return L("運勢", "Luck", "Suerte", "Sorte")
        case .chart: return L("命盤", "Chart", "Carta", "Carta")
        case .match: return L("合盤", "Synastry", "Sinastría", "Sinastria")
        case .me: return L("我", "Me", "Yo", "Io")
        }
    }

    var icon: String {
        switch self {
        case .today: return "sun.max.fill"
        case .luck: return "chart.line.uptrend.xyaxis"
        case .chart: return "circle.grid.3x3.fill"
        case .match: return "person.2.fill"
        case .me: return "person.crop.circle.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: Store
    @State private var tab: AppTab = .today
    /// 只有打開過的分頁才建立，啟動時只需畫出「今天」
    @State private var loaded: Set<AppTab> = [.today]

    var body: some View {
        ZStack {
            ZBackground()
            if store.owner == nil {
                SetupView()
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    // 打開過的分頁常駐，切換時只淡入淡出，保留各自的捲動位置
                    ZStack {
                        TodayTab().tabLayer(tab == .today)
                        if loaded.contains(.luck) { LuckTab().tabLayer(tab == .luck) }
                        if loaded.contains(.chart) { ChartTab().tabLayer(tab == .chart) }
                        if loaded.contains(.match) { MatchTab().tabLayer(tab == .match) }
                        if loaded.contains(.me) { MeTab().tabLayer(tab == .me) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    TabBar(tab: Binding(get: { tab }, set: { t in
                        loaded.insert(t)
                        tab = t
                    }))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.owner == nil)
        .id(store.lang)
        .environment(\.locale, store.lang.locale)
    }
}

struct TabBar: View {
    @Binding var tab: AppTab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { t in
                Button {
                    guard tab != t else { return }
                    Z.haptic(.light)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { tab = t }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon)
                            .font(.system(size: 19, weight: .black))
                        Text(t.title)
                            .font(Z.title(11))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundColor(tab == t ? .black : Z.dim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if tab == t {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Z.lime)
                                .padding(.horizontal, 4)
                                .matchedGeometryEffect(id: "tab", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.title)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            Color.black
                .overlay(HazardStripes().frame(height: 4), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

extension View {
    /// 分頁圖層：非目前分頁隱藏且不接收點擊
    func tabLayer(_ active: Bool) -> some View {
        self
            .opacity(active ? 1 : 0)
            .scaleEffect(active ? 1 : 0.98)
            .allowsHitTesting(active)
            .accessibilityHidden(!active)
    }
}

// MARK: - 首次設定

struct SetupView: View {
    @EnvironmentObject private var store: Store
    @State private var name = ""
    @State private var birth = Date(timeIntervalSince1970: 946_684_800)
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WELCOME, PROXY")
                        .font(Z.mono(12))
                        .foregroundColor(Z.lime)
                    Text("Hollow")
                        .font(Z.title(44))
                        .italic()
                        .foregroundColor(Z.text)
                    HazardStripes().frame(height: 10).clipShape(Capsule())
                    Text(L("只要輸入生日，就能看日運、流月、流年與大運。",
                           "Enter your birthday to see your daily, monthly, annual and Luck Pillar readings.",
                           "Introduce tu fecha de nacimiento para ver tu lectura diaria, mensual, anual y de Pilar de Suerte.",
                           "Inserisci la tua data di nascita per vedere la lettura giornaliera, mensile, annuale e del Pilastro della Sorte."))
                        .font(Z.body(15))
                        .foregroundColor(Z.dim)
                }
                .padding(.top, 30)

                ZCard(tag: L("① 你的名字", "① Your name", "① Tu nombre", "① Il tuo nome")) {
                    TextField("", text: $name)
                        .font(Z.title(22))
                        .foregroundColor(.black)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { focused = false }
                }

                ZCard(tag: L("② 你的生日", "② Your birthday", "② Tu fecha de nacimiento", "② La tua data di nascita"), tagColor: Z.orange, accent: Z.orange) {
                    BirthPicker(date: $birth)
                }

                Button {
                    focused = false
                    Z.success()
                    store.owner = Person(name: cleaned(name), birth: BirthDate(from: birth))
                } label: {
                    Text(L("開始  ▶", "Start  ▶", "Empezar  ▶", "Inizia  ▶"))
                }
                .buttonStyle(ZButtonStyle())

                Text(L("資料只存在這台手機，不會上傳。", "Your data stays on this device and is never uploaded.",
                   "Tus datos se quedan en este dispositivo y nunca se envían.", "I tuoi dati restano su questo dispositivo e non vengono mai inviati."))
                    .font(Z.body(12))
                    .foregroundColor(Z.dim)
                    .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }

    private func cleaned(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? L("你", "You", "Tú", "Tu") : t
    }
}

struct BirthPicker: View {
    @Binding var date: Date

    var body: some View {
        DatePicker("", selection: $date, in: BirthRange.range, displayedComponents: .date)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Lang.current.locale)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Z.panel2))
    }
}

enum BirthRange {
    static var range: ClosedRange<Date> {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? Date.distantPast
        return start...Date()
    }
}

extension BirthDate {
    init(from date: Date) {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
    }

    var date: Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }
}
