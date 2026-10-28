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
    @ObservedObject private var store = ModelStore.shared

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
                    brainSection
                    aiSection
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

    // MARK: - 請其他 AI 幫忙

    private var aiSection: some View {
        section(T("請其他 AI 幫忙", "Ask other AIs", "Preguntar a otras IA", "Chiedi ad altre IA") + " · OTHER AIs") {
            Toggle(isOn: $vm.useAPI) {
                label(T("用 AI API 回答", "Answer with AI APIs", "Responder con API de IA", "Rispondi con API IA"), "")
            }
            .tint(Theme.hazard)
            Toggle(isOn: $vm.speakTranslation) {
                label(T("翻譯後念出來", "Read translations aloud", "Leer traducciones en voz alta", "Leggi le traduzioni ad alta voce"), "")
            }
            .tint(Theme.hazard)
            TextField(T("AI 金鑰：一行一把，可以貼好幾把", "AI keys: one per line, paste as many as you like",
                        "Claves de IA: una por línea", "Chiavi IA: una per riga"), text: $vm.aiKeys, axis: .vertical)
                .lineLimit(2...6)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.paper)
                .padding(10)
                .background(Theme.panelHi)
            let found = vm.aiConfig.names
            Text(found.isEmpty ? T("還沒認出任何金鑰", "No keys recognised yet", "Aún no hay claves", "Nessuna chiave ancora")
                               : T("✓ 認出：", "✓ Recognised: ", "✓ Reconocidas: ", "✓ Riconosciute: ") + found.joined(separator: "、"))
                .font(.system(size: 12, weight: .bold)).foregroundColor(found.isEmpty ? Theme.dim : Theme.hazard)
            button(vm.aiTesting ? T("測試中…", "Testing…", "Probando…", "Test in corso…") : T("測試連線", "Test connection", "Probar conexión", "Prova connessione"),
                   color: Theme.hazard) { if !vm.aiTesting { vm.testAI() } }
            if !vm.aiTestResult.isEmpty {
                Text(vm.aiTestResult).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.paper)
                    .textSelection(.enabled)
            }
        }
    }

    private func keyField(_ placeholder: String, _ text: Binding<String>, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(Theme.paper)
        .padding(10)
        .background(Theme.panelHi)
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

    // MARK: - 大腦

    private var brainSection: some View {
        section(T("NineSun 的大腦", "NineSun's brain", "Cerebro de NineSun", "Cervello di NineSun") + " · BRAIN") {
            Toggle(isOn: $vm.useBrain) {
                label(T("用大腦思考（手機上的 AI）", "Think with the on-phone brain", "Pensar con el cerebro local", "Pensa con il cervello locale"), "")
            }
            .tint(Theme.hazard)
            Text(T("大腦是在手機裡跑的語言模型，下載一次之後完全離線、不用 API。NineSun 先算命盤、查常識、上網找資料，再由大腦讀懂你的問題、想好怎麼回答。建議接 Wi-Fi 下載，下載時可以切到別的 App。",
                   "The brain is a language model running on your phone: download once, then fully offline, no API. NineSun computes charts and looks things up, then the brain works out the answer. Use Wi-Fi to download.",
                   "El cerebro es un modelo de lenguaje en tu teléfono: se descarga una vez y funciona sin conexión. Usa Wi-Fi para descargarlo.",
                   "Il cervello è un modello linguistico sul telefono: si scarica una volta e poi funziona offline. Usa il Wi-Fi per scaricarlo."))
                .font(.system(size: 12, weight: .medium)).foregroundColor(Theme.dim)
            ForEach(ModelStore.models) { m in modelRow(m) }
            if store.readyModel != nil {
                button(vm.brainTesting ? T("測試中…", "Testing…", "Probando…", "Test in corso…") : T("測試大腦", "Test the brain", "Probar el cerebro", "Prova il cervello"),
                       color: Theme.hazard) { if !vm.brainTesting { vm.testBrain() } }
                if !vm.brainTestResult.isEmpty {
                    Text(vm.brainTestResult).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.paper).textSelection(.enabled)
                }
            }
        }
    }

    @ViewBuilder private func modelRow(_ m: ModelStore.Model) -> some View {
        let st = store.states[m.id] ?? .absent
        let chosen = store.selectedID == m.id
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text((chosen ? "● " : "○ ") + m.name).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.paper)
                Spacer()
                Text(ModelStore.gb(m.bytes)).font(Theme.hud(12)).foregroundColor(Theme.dim)
            }
            Text(m.detail).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.dim)
            switch st {
            case .absent:
                button(T("下載", "Download", "Descargar", "Scarica")) { store.selectedID = m.id; store.download(m) }
            case .downloading(let done, let total):
                ProgressView(value: total > 0 ? Double(done) / Double(total) : 0).tint(Theme.hazard)
                HStack {
                    Text("\(ModelStore.gb(done)) / \(ModelStore.gb(total))").font(Theme.hud(11)).foregroundColor(Theme.paper)
                    Spacer()
                    button(T("取消", "Cancel", "Cancelar", "Annulla"), color: Theme.panelHi) { store.cancel(m) }
                }
            case .ready:
                HStack {
                    if chosen {
                        Text(T("✓ 使用中", "✓ In use", "✓ En uso", "✓ In uso")).font(.system(size: 13, weight: .black)).foregroundColor(Theme.hazard)
                    } else {
                        button(T("用這個", "Use this", "Usar este", "Usa questo")) { store.selectedID = m.id }
                    }
                    Spacer()
                    button(T("刪除", "Delete", "Borrar", "Elimina"), color: Theme.neonPink) { store.delete(m) }
                }
            case .failed(let why):
                Text(why).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.neonPink)
                button(T("再下載一次", "Try again", "Reintentar", "Riprova")) { store.selectedID = m.id; store.download(m) }
            }
        }
        .padding(.vertical, 4)
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
