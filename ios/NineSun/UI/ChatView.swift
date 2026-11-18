import EchoCore
import SwiftUI

struct ChatView: View {
    @EnvironmentObject var vm: ChatViewModel
    @State private var input = ""
    @State private var showSettings = false
    @State private var showChart = false
    @State private var showLangPicker = false
    @FocusState private var focused: Bool
    /// 回答寫到一半往上滑去看前面：不要一直把畫面拉回最新的字；滑回最下面、按「↓」或送出新訊息時才再跟著
    @State private var follow = true
    @State private var track = ChatScrollTrack()

    private var quick: [String] {
        switch vm.language {
        case .zh: return ["幫我做完整解讀", "今天運勢", "今晚運勢", "明天運勢", "這週運勢", "這個月運勢", "今年運勢", "我今年感情運如何",
                          "今年哪個月最好", "我什麼時候會結婚", "這個月哪天適合告白", "今年和明年哪個好", "我今年哪方面比較順",
                          "我的大運", "我的命盤", "我壓力大的時候會怎樣", "我適合什麼工作", "我的八字", "我的八字今年運勢", "紫微斗數", "紫微今年運勢", "算一卦"]
        case .en: return ["today's fortune", "tomorrow's fortune", "how's my love life this year", "my career this year", "this month's fortune",
                          "my luck pillar", "my chart", "my bazi", "my zi wei", "cast a hexagram", "my portrait"]
        case .es: return ["mi suerte de hoy", "la suerte de mañana", "mi amor este año", "mi trabajo este año", "suerte de este mes",
                          "mi pilar de suerte", "mi carta", "mi bazi", "mi zi wei", "tira un hexagrama", "mi retrato"]
        case .it: return ["fortuna di oggi", "fortuna di domani", "il mio amore quest'anno", "il mio lavoro quest'anno", "fortuna di questo mese",
                          "il mio pilastro della sorte", "il mio tema", "il mio bazi", "il mio zi wei", "lancia un esagramma", "il mio ritratto"]
        }
    }

    var body: some View {
        ZStack {
            HalftoneBackground()
            VStack(spacing: 0) {
                header
                messages
                quickBar
                inputBar
            }
            if showLangPicker { langPicker }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(vm)
        }
        .sheet(isPresented: $showChart) {
            FortuneView().environmentObject(vm)
        }
    }

    // MARK: - 頂部

    private var mood: TVAvatar.Mood {
        if vm.streaming?.isEmpty == false { return .talking }
        return vm.thinking ? .thinking : .idle
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                TVAvatar(mood: mood, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("NineSun").font(Theme.display(24)).foregroundColor(Theme.paper)
                            .lineLimit(1).minimumScaleFactor(0.6).fixedSize(horizontal: true, vertical: false)
                        TagLabel(text: vm.thinking ? "RECEIVING" : "ONLINE",
                                 bg: vm.thinking ? Theme.orange : Theme.hazard)
                    }
                    Text(vm.profile.birthday.map { T("命主 ", "Native ", "Nativo ", "Nativo ") + $0.display + (vm.profile.hour.map { " \($0)" + T("時", "h", "h", "h") } ?? "") }
                         ?? T("底層 · 九型十二宮認知核心", "Core · Nine & Twelve cognition", "Núcleo · cognición Nueve y Doce", "Nucleo · cognizione Nove e Dodici"))
                        .font(Theme.hud(10))
                        .foregroundColor(Theme.dim)
                }
                Spacer()
                SignalBars(active: !vm.thinking)
                // 資料庫的按鈕：打開命盤（今日、本命、性格、大運、合盤）
                Button {
                    showChart = true
                } label: {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.hazard)
                        .frame(width: 38, height: 34)
                        .background(Slanted(skew: 7).fill(Theme.panelHi))
                }
                .accessibilityLabel(T("命盤", "Chart", "Carta", "Tema"))
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "dial.medium.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.ink)
                        .frame(width: 42, height: 34)
                        .background(Slanted(skew: 7).fill(Theme.hazard))
                }
                .accessibilityLabel(T("調頻台", "Tuning", "Ajustes", "Impostazioni"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            HazardStripes(height: 6)
        }
        .background(Theme.ink.opacity(0.92))
    }

    // MARK: - 訊息

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(vm.turns) { t in
                        MessageBubble(turn: t).id(t.id)
                    }
                    if let s = vm.streaming {
                        MessageBubble(turn: ChatTurn(role: .echo, text: s.isEmpty ? "▮" : s + "▮"), live: true)
                            .id("live")
                    }
                    Color.clear.frame(height: 4).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                // 內容在可見範圍裡的位置：用來知道使用者是不是還在最下面
                .background(GeometryReader { g in
                    Color.clear.preference(key: ChatContentFrameKey.self, value: g.frame(in: .named("chatScroll")))
                })
            }
            .coordinateSpace(name: "chatScroll")
            .background(GeometryReader { g in
                Color.clear.preference(key: ChatViewportHeightKey.self, value: g.size.height)
            })
            .onPreferenceChange(ChatViewportHeightKey.self) { h in track.viewport = h }
            .onPreferenceChange(ChatContentFrameKey.self) { f in
                // 回答每 0.018 秒多幾個字：只要往上滑一點點（內容往下移）就馬上停止跟著，不能等滑超過某個距離——
                // 不然下一個字一出來又被拉回去（第 493 版就是這樣）。往下滑回到最下面才再跟著。只是字變多（上緣不動）不算捲動。
                let dy = f.minY - track.lastTop
                let shrank = f.height < track.lastHeight - 0.5
                track.lastTop = f.minY
                track.lastHeight = f.height
                // 內容變短（回答寫完、游標「▮」拿掉）時捲動區自己往下靠：不是使用者在滑
                guard abs(dy) > 0.5, !shrank, Date() >= track.ignoreUntil else { return }
                if dy > 0 {
                    if follow { follow = false }
                } else if f.maxY - track.viewport < 40, !track.dragging {
                    if !follow { follow = true }
                }
            }
            // iOS 18 以上：直接用系統的捲動狀態——手指在滑就不跟；放開時人在最下面才再跟
            .modifier(ChatScrollPhaseWatcher(follow: $follow, track: track))
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: vm.turns.count) { _ in
                // 自己送出新訊息：回到最下面、跟著回答；回答寫完時，只有本來就在最下面才捲
                if vm.turns.last?.role == .user { follow = true }
                if follow { scrollDown(proxy) }
            }
            .onChange(of: vm.streaming) { _ in
                if follow { scrollDown(proxy, animated: false) }
            }
            .onAppear { scrollDown(proxy, animated: false) }
            // 往上滑在看前面的內容時：右下角的「↓」一按就回到最新的地方
            .overlay(alignment: .bottomTrailing) {
                if !follow {
                    Button {
                        follow = true
                        scrollDown(proxy)
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Theme.hazard))
                            .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                    .accessibilityLabel("回到最新的訊息")
                }
            }
            // 點聊天內容或上下捲動都會把鍵盤收起來；按鈕照常可按
            .simultaneousGesture(TapGesture().onEnded { focused = false })
        }
    }

    private func scrollDown(_ proxy: ScrollViewProxy, animated: Bool = true) {
        // 有動畫的捲動途中，位置一格一格變：這段時間不要拿來判斷「使用者滑走了」
        if animated { track.ignoreUntil = Date().addingTimeInterval(0.45) }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }

    // MARK: - 快捷

    private var quickBar: some View {
        HStack(spacing: 0) {
            translateButton.padding(.leading, 16)
            quickChips
        }
    }

    /// 翻譯按鈕：點一下開／關（亮黃綠色＝開），長按跳出絕區零風格的語言面板
    private var translateButton: some View {
        let cur = ChatViewModel.translateLangs.first { $0.code == vm.translateTarget } ?? ChatViewModel.translateLangs[1]
        return HStack(spacing: 4) {
            Image(systemName: "globe").font(.system(size: 12, weight: .black))
            Text(cur.short).font(.system(size: 13, weight: .black))
        }
        .foregroundColor(vm.translateOn ? Theme.ink : Theme.dim)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Slanted(skew: 6).fill(vm.translateOn ? Theme.hazard : Theme.panel))
        .overlay(Slanted(skew: 6).stroke(vm.translateOn ? Theme.hazard : Theme.panelHi, lineWidth: 1))
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { showLangPicker = true }
                }
                .exclusively(before: TapGesture().onEnded {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    vm.translateOn.toggle()
                })
        )
    }

    /// 長按後的語言面板：警示條紋標題、斜切按鈕，選中的亮黃綠色
    private var langPicker: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { showLangPicker = false } }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TagLabel(text: "TRANSLATE", fg: Theme.ink, bg: Theme.signal)
                    Text(T("翻譯成", "TRANSLATE TO", "TRADUCIR AL", "TRADURRE IN")).font(Theme.hud(11)).foregroundColor(Theme.dim)
                }
                HazardStripes(height: 5)
                ForEach(ChatViewModel.translateLangs, id: \.self) { l in
                    let on = l.code == vm.translateTarget
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        vm.translateTarget = l.code
                        vm.translateOn = true
                        withAnimation(.easeOut(duration: 0.18)) { showLangPicker = false }
                    } label: {
                        HStack(spacing: 10) {
                            Text(l.short).font(Theme.display(16)).frame(width: 34, alignment: .leading)
                            Text(l.name).font(.system(size: 16, weight: .heavy))
                            Spacer()
                            if on { Image(systemName: "play.fill").font(.system(size: 11, weight: .black)) }
                        }
                        .foregroundColor(on ? Theme.ink : Theme.paper)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Slanted(skew: 8).fill(on ? Theme.hazard : Theme.panelHi))
                        .overlay(Slanted(skew: 8).stroke(on ? Theme.orange : Color.white.opacity(0.08), lineWidth: 1.5))
                    }
                }
            }
            .padding(14)
            .frame(width: 250)
            .background(NotchedPanel(cut: 14).fill(Theme.panel))
            .overlay(NotchedPanel(cut: 14).stroke(Theme.hazard.opacity(0.7), lineWidth: 1.5))
            .overlay(alignment: .leading) { Rectangle().fill(Theme.signal).frame(width: 3) }
            .padding(.leading, 16)
            .padding(.bottom, 128)
            .transition(.scale(scale: 0.85, anchor: .bottomLeading).combined(with: .opacity))
        }
    }

    private var quickChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quick, id: \.self) { q in
                    Button { vm.send(q) } label: {
                        Text(q)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(Theme.hazard)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Slanted(skew: 6).fill(Theme.panel))
                            .overlay(Slanted(skew: 6).stroke(Theme.hazard.opacity(0.6), lineWidth: 1))
                    }
                    .disabled(!vm.canSend)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 輸入

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("", text: $input, prompt: Text(vm.translateOn
                    ? T("直接輸入，翻成", "Type to translate into ", "Escribe para traducir al ", "Scrivi per tradurre in ")
                        + (ChatViewModel.translateLangs.first { $0.code == vm.translateTarget }?.name ?? "")
                    : T("對 NineSun 發送訊號…", "Send a signal to NineSun…", "Envía una señal a NineSun…", "Invia un segnale a NineSun…")).foregroundColor(Theme.dim), axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.paper)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit(submit)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(NotchedPanel(cut: 10).fill(Theme.panel))
                .overlay(NotchedPanel(cut: 10).stroke(focused ? Theme.hazard : Theme.panelHi, lineWidth: 1.5))

            Button(action: submit) {
                HStack(spacing: 4) {
                    Text("SEND").font(Theme.display(15))
                    Image(systemName: "play.fill").font(.system(size: 11, weight: .black))
                }
                .foregroundColor(Theme.ink)
                .frame(width: 84, height: 44)
                .background(Slanted(skew: 10).fill(vm.canSend && !input.isEmpty ? Theme.hazard : Theme.panelHi))
            }
            .disabled(!vm.canSend || input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(Theme.ink.opacity(0.92))
    }

    private func submit() {
        let t = input
        input = ""
        vm.send(t)
    }
}

/// 訊號強度條。
struct SignalBars: View {
    var active: Bool
    @State private var t = 0
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4) { i in
                Rectangle()
                    .fill(active || (t + i) % 4 != 0 ? Theme.hazard : Theme.panelHi)
                    .frame(width: 4, height: CGFloat(6 + i * 4))
            }
        }
        .onReceive(Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()) { _ in t += 1 }
    }
}

// MARK: - 捲動位置（回答寫到一半往上滑時，不要一直被拉回最下面）

/// 聊天內容在可見範圍裡的位置（座標系是捲動區本身）
private struct ChatContentFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

/// 捲動區看得到的高度
private struct ChatViewportHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// 捲動時一直在變、但不需要重畫畫面的數字（放在 class 裡，改了不會觸發重畫）
private final class ChatScrollTrack {
    var lastTop: CGFloat = 0
    var lastHeight: CGFloat = 0
    var viewport: CGFloat = 0
    /// 手指正在滑（iOS 18 以上才知道）
    var dragging = false
    /// 人在最下面（iOS 18 以上由系統的捲動位置算）
    var atBottom = true
    /// 程式自己有動畫地捲到最下面時，這段時間的位置變化不算使用者滑走
    var ignoreUntil = Date.distantPast
}

/// iOS 18 以上用系統的捲動狀態判斷使用者是不是在滑；舊的系統什麼都不做（靠上面的位置判斷）
private struct ChatScrollPhaseWatcher: ViewModifier {
    @Binding var follow: Bool
    let track: ChatScrollTrack

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollGeometryChange(for: Bool.self, of: { g in
                    g.visibleRect.maxY >= g.contentSize.height - 40
                }, action: { _, bottom in
                    track.atBottom = bottom
                })
                .onScrollPhaseChange { _, phase in
                    switch phase {
                    case .tracking, .interacting:
                        track.dragging = true
                        if follow { follow = false }
                    case .idle:
                        track.dragging = false
                        if track.atBottom, !follow { follow = true }
                    default:
                        track.dragging = false
                    }
                }
        } else {
            content
        }
    }
}
