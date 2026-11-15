import SwiftUI

struct AutoView: View {
    @EnvironmentObject var store: WallStore
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var center: ApplyCenter
    @AppStorage(Keys.lastSwitch) private var lastSwitch: Double = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AUTO SWITCH").font(.mono(11)).tracking(3).foregroundStyle(Theme.dim)
                    Text("自動換台").font(.display(30)).foregroundStyle(Theme.paper)
                }

                note

                section(code: "01", title: "換台順序") {
                    HStack(spacing: 8) {
                        ForEach(PickMode.allCases) { m in
                            Button {
                                Haptics.tap()
                                store.setMode(m)
                            } label: {
                                VStack(spacing: 2) {
                                    Text(m.code).font(.mono(9)).opacity(0.7)
                                    Text(m.label).font(.display(17))
                                }
                                .foregroundStyle(store.mode == m ? Theme.ink : Theme.paper)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Slant(cut: 10).fill(store.mode == m ? Theme.acid : Theme.panel2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text(modeHint).font(.mono(11)).foregroundStyle(Theme.dim)
                }

                section(code: "02", title: "自動套用到") {
                    HStack(spacing: 8) {
                        ForEach(WallTarget.allCases) { t in
                            Button {
                                Haptics.tap()
                                center.autoTarget = t
                            } label: {
                                VStack(spacing: 3) {
                                    Image(systemName: t.icon).font(.system(size: 15, weight: .heavy))
                                    Text(t.short).font(.display(14)).lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .foregroundStyle(center.autoTarget == t ? Theme.ink : Theme.paper)
                                .frame(maxWidth: .infinity, minHeight: 56)
                                .background(Slant(cut: 9).fill(center.autoTarget == t ? Theme.acid : Theme.panel2))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if !center.isReady(center.autoTarget) {
                        Button {
                            center.openSetup(center.autoTarget)
                        } label: {
                            Label("先安裝「\(center.autoTarget.shortcut)」", systemImage: "exclamationmark.triangle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SlantButtonStyle(fill: Theme.hot, outline: true))
                    } else {
                        Text("> 「\(center.autoTarget.shortcut)」已可用").font(.mono(11)).foregroundStyle(Theme.acid)
                    }
                }

                section(code: "03", title: "安裝自動捷徑（一次）") {
                    step("1", "按下面按鈕，在分享選單選「捷徑」(Comandi rapidi) → 「加入捷徑」。")
                    if let file = ApplyCenter.autoBundled {
                        ShareLink(item: file) {
                            Label("安裝『\(ApplyCenter.autoShortcut)』", systemImage: "square.and.arrow.down.on.square")
                                .font(.display(18))
                                .foregroundStyle(Theme.ink)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(Slant().fill(Theme.acid))
                        }
                    }
                    Text("它只做一件事：打開本 App → 換到下一台 → 用上面選的方式套用。")
                        .font(.mono(11)).foregroundStyle(Theme.dim)
                }

                section(code: "04", title: "建立自動化（一次）") {
                    step("1", "打開「捷徑」→ 下方「自動化」(Automazione) → 右上 ＋")
                    step("2", "選觸發條件，例如「時間」(Ora del giorno) 每天 08:00，或「App」→ 打開某個 App 時")
                    step("3", "選「立即執行」(Esegui immediatamente)，關閉「執行時通知」")
                    step("4", "下一步選「潮流自動換壁紙」→ 完成 (Fine)")
                    Text("iOS 不允許 App 自己建立自動化，所以這 4 步要手動做一次。手機解鎖時觸發最穩定。")
                        .font(.mono(11)).foregroundStyle(Theme.dim)
                }

                Button {
                    center.showHomeGuide = true
                } label: {
                    Label("主畫面是純色？一次設定", systemImage: "square.grid.2x2.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(SlantButtonStyle(fill: Theme.cyan, outline: true))

                HStack(spacing: 10) {
                    Button {
                        Haptics.tap()
                        center.openShortcuts()
                    } label: {
                        Label("打開捷徑", systemImage: "square.stack.3d.up.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SlantButtonStyle())

                    Button {
                        center.runAuto(toaster: toaster)
                    } label: {
                        Label("立即試跑", systemImage: "forward.end.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SlantButtonStyle(fill: Theme.paper, outline: true))
                }

                if lastSwitch > 0 {
                    Text("上次換台：\(Date(timeIntervalSinceReferenceDate: lastSwitch).formatted(date: .abbreviated, time: .shortened))")
                        .font(.mono(10)).foregroundStyle(Theme.dim)
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
    }

    private var modeHint: String {
        let n = Catalog.all.count
        switch store.mode {
        case .sequential: return "> 01 → 02 → … → \(n) → 01 依序換台"
        case .random: return "> 從 \(n) 張裡隨機抽，不會連續重複"
        case .favorites: return "> 只在收藏的壁紙中隨機（沒收藏時用全部）"
        }
    }

    private var note: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(Theme.ink)
            Text("設定一次，之後每天自動換壁紙：自動化觸發 →「潮流自動換壁紙」→ 本 App 換台並套用。")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CutPanel(cut: 12).fill(Theme.acid))
    }

    private func section<Content: View>(code: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Tag(text: code)
                Text(title).font(.display(21)).foregroundStyle(Theme.paper)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CutPanel(cut: 14).fill(Theme.panel))
        .overlay(CutPanel(cut: 14).stroke(Theme.line, lineWidth: 1))
    }

    private func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(n)
                .font(.mono(11))
                .foregroundStyle(Theme.acid)
                .frame(width: 22, height: 22)
                .overlay(Rectangle().stroke(Theme.acid, lineWidth: 1.5).rotationEffect(.degrees(45)).scaleEffect(0.75))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
