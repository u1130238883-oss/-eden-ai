import EchoCore
import SwiftUI

/// 調頻台：語言、命主資料、清空對話。
struct SettingsView: View {
    @EnvironmentObject var vm: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var time = Date()
    @State private var knowsTime = false
    @State private var gender = 0          // 0 未設定 1 男 2 女
    @State private var dateTouched = false
    @State private var isLoading = true
    @State private var confirmClear = false

    var body: some View {
        ZStack {
            HalftoneBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        GlitchText(text: T("調頻台", "TUNING", "AJUSTES", "SINTONIA"), size: 30)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 16, weight: .black))
                                .foregroundColor(Theme.ink).frame(width: 40, height: 32)
                                .background(Slanted(skew: 6).fill(Theme.hazard))
                        }
                    }
                    HazardStripes(height: 6)

                    languageSection
                    profileSection
                    section(T("記憶", "Memory", "Memoria", "Memoria") + " · MEMORY") {
                        button(T("清空對話", "Clear chat", "Borrar chat", "Cancella chat"), color: Theme.neonPink) { confirmClear = true }
                    }

                    Text(T("命理內容僅供娛樂與自我覺察參考。", "Readings are for entertainment and self-reflection only.", "Las lecturas son solo para entretenimiento y autorreflexión.", "Le letture sono solo per intrattenimento e riflessione personale.")).font(Theme.hud(10)).foregroundColor(Theme.dim)
                }
                .padding(16)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: load)
        .alert(T("清空所有對話？", "Clear all messages?", "¿Borrar todos los mensajes?", "Cancellare tutti i messaggi?"), isPresented: $confirmClear) {
            Button(T("清空", "Clear", "Borrar", "Cancella"), role: .destructive) { vm.clear() }
            Button(T("取消", "Cancel", "Cancelar", "Annulla"), role: .cancel) {}
        }
    }

    // MARK: - 語言

    private var languageSection: some View {
        section(T("語言", "Language", "Idioma", "Lingua") + " · LANGUAGE") {
            Picker(T("介面語言", "Interface language", "Idioma de la interfaz", "Lingua dell'interfaccia"), selection: $vm.language) {
                ForEach(Lang.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle(isOn: $vm.autoDetect) {
                label(T("自動偵測訊息語言", "Auto-detect message language", "Detectar idioma del mensaje", "Rileva lingua del messaggio"), "")
            }
            .tint(Theme.hazard)
            Text(T("開啟時，NineSun 用你每則訊息的語言回覆；關閉時固定用介面語言。",
                   "When on, NineSun replies in the language of each message; when off, it always uses the interface language.",
                   "Activado, NineSun responde en el idioma de cada mensaje; desactivado, usa siempre el idioma de la interfaz.",
                   "Attivo: NineSun risponde nella lingua di ogni messaggio; disattivo: usa sempre la lingua dell'interfaccia."))
                .font(.system(size: 12, weight: .medium)).foregroundColor(Theme.dim)
        }
    }

    // MARK: - 命主

    private var profileSection: some View {
        section(T("命主", "Native", "Nativo", "Nativo") + " · PROFILE") {
            if let b = vm.profile.birthday {
                Text(T("✓ 已記住生日 ", "✓ Birthday saved: ", "✓ Cumpleaños guardado: ", "✓ Compleanno salvato: ") + b.display
                     + (vm.profile.hour.map { String(format: "  %02d:%02d", $0, vm.profile.minute ?? 0) } ?? ""))
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.hazard)
            } else {
                Text(T("尚未設定生日：選好日期後會自動儲存，AI 就不會再問你。",
                       "No birthday yet: pick a date and it saves automatically, so the AI won't ask again.",
                       "Aún sin cumpleaños: elige una fecha y se guarda sola; la IA no volverá a preguntar.",
                       "Nessun compleanno: scegli una data e si salva da sola; l'IA non lo chiederà più."))
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.orange)
            }
            DatePicker(T("生日", "Birthday", "Cumpleaños", "Compleanno"), selection: $date, in: range, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: ["zh": "zh_Hant", "en": "en", "es": "es", "it": "it"][vm.language.rawValue] ?? "en"))
                .foregroundColor(Theme.paper).tint(Theme.hazard)
                .onChange(of: date) { _ in
                    guard !isLoading else { return }
                    dateTouched = true
                    saveProfile()
                }
            Toggle(isOn: $knowsTime) { label(T("知道出生時間（八字時柱、紫微需要）", "I know my birth time (needed for BaZi hour & Zi Wei)", "Sé mi hora de nacimiento (para BaZi y Zi Wei)", "So l'ora di nascita (serve per BaZi e Zi Wei)"), "") }.tint(Theme.hazard)
                .onChange(of: knowsTime) { _ in if !isLoading { saveProfile() } }
            if knowsTime {
                DatePicker(T("出生時間", "Birth time", "Hora de nacimiento", "Ora di nascita"), selection: $time, displayedComponents: .hourAndMinute)
                    .foregroundColor(Theme.paper).tint(Theme.hazard)
                    .onChange(of: time) { _ in if !isLoading { saveProfile() } }
            }
            Picker(T("性別", "Gender", "Género", "Genere"), selection: $gender) {
                Text(T("未設定", "Unset", "Sin definir", "Non impostato")).tag(0)
                Text(T("男", "Male", "Hombre", "Uomo")).tag(1)
                Text(T("女", "Female", "Mujer", "Donna")).tag(2)
            }
            .pickerStyle(.segmented)
            .onChange(of: gender) { _ in if !isLoading { saveProfile() } }
            HStack {
                button(vm.profile.birthday == nil ? T("儲存這個生日", "Save this birthday", "Guardar este cumpleaños", "Salva questo compleanno") : T("已自動儲存", "Auto-saved", "Guardado automático", "Salvato automaticamente")) {
                    dateTouched = true
                    saveProfile()
                }
                if vm.profile.birthday != nil {
                    button(T("清除", "Clear", "Borrar", "Cancella"), color: Theme.panelHi) {
                        vm.profile = UserProfile()
                        dateTouched = false
                        load()
                    }
                }
            }
            if let b = vm.profile.birthday {
                let d = Destiny(b)
                Text(vm.language == .zh ? "\(b.display)　命宮 \(NT.label(d.natal[0].palace))　第\(d.type)型「\(NT.typeName(d.type))」"
                     : "\(b.display)  " + T("", "Life palace", "Palacio de vida", "Palazzo della vita") + " \(d.natal[0].palace)  " + T("", "Type", "Tipo", "Tipo") + " \(d.type)")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Theme.hazard)
            }
        }
    }

    private func load() {
        isLoading = true
        let cal = Calendar(identifier: .gregorian)
        let b = vm.profile.birthday ?? BirthDay(year: 2000, month: 1, day: 1)
        date = cal.date(from: DateComponents(year: b.year, month: b.month, day: b.day)) ?? Date()
        knowsTime = vm.profile.hour != nil
        time = cal.date(from: DateComponents(hour: vm.profile.hour ?? 12, minute: vm.profile.minute ?? 0)) ?? Date()
        gender = vm.profile.male.map { $0 ? 1 : 2 } ?? 0
        // 等 SwiftUI 處理完這批賦值後才開始接受使用者的更動
        DispatchQueue.main.async { isLoading = false }
    }

    /// 生日、時間、性別一有更動就存進去；沒選過日期就不會擅自寫入 2000/1/1
    private func saveProfile() {
        let cal = Calendar(identifier: .gregorian)
        var p = vm.profile
        if dateTouched || p.birthday != nil {
            let c = cal.dateComponents([.year, .month, .day], from: date)
            p.birthday = BirthDay(year: c.year!, month: c.month!, day: c.day!)
        }
        let t = cal.dateComponents([.hour, .minute], from: time)
        p.hour = knowsTime ? t.hour : nil
        p.minute = knowsTime ? t.minute : nil
        p.male = gender == 0 ? nil : gender == 1
        vm.profile = p
    }

    private var range: ClosedRange<Date> {
        let cal = Calendar(identifier: .gregorian)
        return (cal.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? .distantPast)...Date()
    }

    // MARK: - 元件

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TagLabel(text: title)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NotchedPanel(cut: 14).fill(Theme.panel.opacity(0.95)))
    }

    private func label(_ l: String, _ v: String) -> some View {
        HStack {
            Text(l).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.paper)
            Spacer()
            Text(v).font(Theme.hud(13)).foregroundColor(Theme.hazard)
        }
    }

    private func info(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) {
            Text(k).font(Theme.hud(11)).foregroundColor(Theme.dim).frame(width: 96, alignment: .leading)
            Text(v).font(.system(size: 13, weight: .semibold)).foregroundColor(Theme.paper)
        }
    }

    private func slider(_ l: String, value: Binding<Float>, in r: ClosedRange<Float>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            label(l, String(format: format, value.wrappedValue))
            Slider(value: value, in: r).tint(Theme.hazard)
        }
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
