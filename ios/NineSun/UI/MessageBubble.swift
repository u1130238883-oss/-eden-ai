import EchoCore
import SwiftUI

struct MessageBubble: View {
    @EnvironmentObject var vm: ChatViewModel
    let turn: ChatTurn
    var live = false

    var body: some View {
        if turn.role == .user {
            HStack {
                Spacer(minLength: 48)
                Text(turn.text)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.ink)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Slanted(skew: 10).fill(Theme.hazard))
                    .background(Slanted(skew: 10).fill(Theme.orange).offset(x: 4, y: 4))
                    .textSelection(.enabled)
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        TagLabel(text: "NINESUN", fg: Theme.ink, bg: Theme.signal)
                        if let badge { TagLabel(text: badge.0, fg: badge.2, bg: badge.1) }
                        if let p = turn.palace {
                            TagLabel(text: UILang.current == .zh ? "感 \(NT.label(p))" : T("", "PALACE \(p)", "PALACIO \(p)", "PALAZZO \(p)"), fg: Theme.hazard, bg: Theme.panelHi)
                        }
                    }
                    Text(turn.text)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.paper)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    if let card = turn.card {
                        FortuneCardView(card: card)
                    }
                    if !live, turn.tokens != nil {
                        feedbackBar
                    }
                }
                .padding(14)
                .background(NotchedPanel(cut: 14).fill(Theme.panel.opacity(0.95)))
                .overlay(alignment: .leading) {
                    Rectangle().fill(live ? Theme.orange : Theme.signal).frame(width: 3)
                }
                .overlay(NotchedPanel(cut: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
                Spacer(minLength: 20)
            }
        }
    }

    private var feedbackBar: some View {
        HStack(spacing: 10) {
            ForEach([true, false], id: \.self) { up in
                Button {
                    vm.feedback(turn, positive: up)
                } label: {
                    Image(systemName: up ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(turn.liked == up ? Theme.ink : Theme.dim)
                        .frame(width: 34, height: 22)
                        .background(Slanted(skew: 4).fill(turn.liked == up ? (up ? Theme.hazard : Theme.neonPink) : Theme.panelHi))
                }
                .disabled(turn.liked != nil)
            }
            if turn.liked != nil {
                Text(turn.query != nil
                     ? T("已記進經驗：下次會調整查法和信任的網站", "Learned: I'll adjust how I search next time", "Aprendido: ajustaré cómo busco", "Imparato: cambierò come cerco")
                     : T("已寫入演化權重", "Written into evolution weights", "Guardado en los pesos de evolución", "Scritto nei pesi di evoluzione"))
                    .font(Theme.hud(10)).foregroundColor(Theme.dim)
            }
        }
    }

    private var badge: (String, Color, Color)? {
        switch turn.source {
        case .grounded: return (T("命理核 ✓", "ENGINE ✓", "MOTOR ✓", "MOTORE ✓"), Theme.hazard, Theme.ink)
        case .corrected: return (T("引擎校正", "CORRECTED", "CORREGIDO", "CORRETTO"), Theme.orange, Theme.ink)
        case .knowledge: return (T("資料庫", "LIBRARY", "BIBLIOTECA", "BIBLIOTECA"), Theme.signal, Theme.ink)
        case .rule: return (T("規則", "RULE", "REGLA", "REGOLA"), Theme.neonPink, Theme.ink)
        case .reader: return (T("十二宮解讀", "NINE·TWELVE", "NUEVE·DOCE", "NOVE·DODICI"), Theme.hazard, Theme.ink)
        case .tool: return ("SYS", Theme.panelHi, Theme.paper)
        case .neural: return nil
        }
    }
}

/// 結果卡：電視螢幕造型，數值全部來自引擎。
struct FortuneCardView: View {
    let card: FortuneCard
    @State private var expanded = false
    @Environment(\.openURL) private var openURL

    private var color: Color {
        switch card.verdict {
        case .good: return Theme.hazard
        case .bad: return Theme.neonPink
        case .neutral: return Theme.signal
        case nil: return Theme.signal
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(card.title).font(Theme.hud(11)).foregroundColor(Theme.ink).lineLimit(1)
                Spacer()
                if let v = card.verdict { Text(v.name).font(Theme.display(14)).foregroundColor(Theme.ink) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)

            VStack(alignment: .leading, spacing: 8) {
                Text(card.headline)
                    .font(Theme.display(19))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.6), radius: 6)
                if let p = card.pillars { PillarsView(pillars: p, gods: card.pillarGods ?? []) }
                if let l = card.hexLines { HexagramView(lines: l, moving: card.hexMoving ?? []) }
                if let z = card.ziwei { ZiWeiGrid(cells: z) }
                let shown = expanded ? card.details : Array(card.details.prefix(5))
                ForEach(Array(shown.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.paper.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if card.details.count > 5 {
                    Button(expanded ? T("收合 ▲", "Collapse ▲", "Contraer ▲", "Comprimi ▲") : T("展開全部 ▼", "Show all ▼", "Ver todo ▼", "Mostra tutto ▼")) {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    }
                    .font(Theme.hud(11))
                    .foregroundColor(color)
                }
                if let code = card.code {
                    ScrollView(.horizontal) {
                        Text(code)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Theme.hazard.opacity(0.9))
                            .textSelection(.enabled)
                            .padding(8)
                    }
                    .frame(maxHeight: expanded ? 600 : 180)
                    .background(Color.black.opacity(0.5))
                    Button(expanded ? T("收合程式碼 ▲", "Hide code ▲", "Ocultar código ▲", "Nascondi codice ▲") : T("展開程式碼 ▼", "Show code ▼", "Ver código ▼", "Mostra codice ▼")) {
                        withAnimation { expanded.toggle() }
                    }
                    .font(Theme.hud(11)).foregroundColor(color)
                }
                if let link = card.link, let url = URL(string: link) {
                    Button {
                        openURL(url)
                    } label: {
                        HStack(spacing: 4) {
                            Text(T("開啟連結", "Open link", "Abrir enlace", "Apri link")).font(.system(size: 13, weight: .black))
                            Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .black))
                        }
                        .foregroundColor(Theme.ink)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Slanted(skew: 6).fill(color))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    Theme.ink
                    VStack(spacing: 3) {
                        ForEach(0..<60, id: \.self) { _ in Rectangle().fill(color.opacity(0.05)).frame(height: 1) }
                    }
                }
                .clipped()
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.7), lineWidth: 1.5))
    }
}

/// 八字四柱
struct PillarsView: View {
    let pillars: [String]
    let gods: [String]
    private var labels: [String] { [T("年柱", "Year", "Año", "Anno"), T("月柱", "Month", "Mes", "Mese"), T("日柱", "Day", "Día", "Giorno"), T("時柱", "Hour", "Hora", "Ora")] }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(pillars.enumerated()), id: \.offset) { i, p in
                VStack(spacing: 2) {
                    Text(i < gods.count ? gods[i] : "").font(Theme.hud(9)).foregroundColor(Theme.dim)
                    Text(String(p.prefix(1))).font(.system(size: 26, weight: .black)).foregroundColor(i == 2 ? Theme.hazard : Theme.paper)
                    Text(String(p.suffix(1))).font(.system(size: 26, weight: .black)).foregroundColor(Theme.signal)
                    Text(labels[i]).font(Theme.hud(9)).foregroundColor(Theme.dim)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Slanted(skew: 5).fill(i == 2 ? Theme.panelHi : Theme.panel))
            }
        }
    }
}

/// 卦象：由下而上六爻，動爻以橘色標示
struct HexagramView: View {
    let lines: [Int]
    let moving: [Int]

    var body: some View {
        VStack(spacing: 6) {
            ForEach((0..<6).reversed(), id: \.self) { i in
                let c = moving.contains(i) ? Theme.orange : Theme.hazard
                HStack(spacing: 10) {
                    if lines[i] == 1 {
                        Rectangle().fill(c).frame(height: 10)
                    } else {
                        Rectangle().fill(c).frame(height: 10)
                        Rectangle().fill(c).frame(height: 10)
                    }
                }
                .frame(width: 150)
                .overlay(alignment: .trailing) {
                    if moving.contains(i) { Text(T("動", "MOV", "MÓV", "MOB")).font(Theme.hud(10)).foregroundColor(Theme.orange).offset(x: 22) }
                }
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
    }
}

/// 紫微命盤：傳統 4×4 排法（外圈 12 宮、中央留白）
struct ZiWeiGrid: View {
    let cells: [ZiWeiCell]
    /// 地支在 4×4 格中的位置（巳午未申在上，亥子丑寅在下）
    private let positions: [Int: (Int, Int)] = [
        5: (0, 0), 6: (0, 1), 7: (0, 2), 8: (0, 3),
        4: (1, 0), 9: (1, 3),
        3: (2, 0), 10: (2, 3),
        2: (3, 0), 1: (3, 1), 0: (3, 2), 11: (3, 3),
    ]

    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { c in
                        if let item = cellAt(r, c) {
                            cellView(item)
                        } else if r == 1 && c == 1 {
                            Text(T("命盤", "CHART", "CARTA", "TEMA")).font(Theme.display(16)).foregroundColor(Theme.hazard.opacity(0.5))
                                .frame(maxWidth: .infinity, minHeight: 64)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 64)
                        }
                    }
                }
            }
        }
    }

    private func cellAt(_ r: Int, _ c: Int) -> ZiWeiCell? {
        cells.first { item in
            guard let p = positions[item.branch] else { return false }
            return p.0 == r && p.1 == c
        }
    }

    private func cellView(_ cell: ZiWeiCell) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(cell.stars.prefix(4), id: \.self) { s in
                Text(s).font(.system(size: 9, weight: .bold))
                    .foregroundColor(s.contains("化") ? Theme.orange : Theme.paper)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Text(cell.palace).font(.system(size: 10, weight: .black))
                    .foregroundColor(cell.isMing ? Theme.ink : Theme.hazard)
                    .padding(.horizontal, 2)
                    .background(cell.isMing ? Theme.hazard : Color.clear)
                if cell.isShen { Text("身").font(.system(size: 9, weight: .black)).foregroundColor(Theme.signal) }
                Spacer(minLength: 0)
                Text(cell.stem + GZ.branches[cell.branch]).font(Theme.hud(8)).foregroundColor(Theme.dim)
            }
        }
        .padding(3)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
        .background(cell.isMing ? Theme.panelHi : Theme.panel)
        .overlay(Rectangle().stroke(cell.isMing ? Theme.hazard : Color.white.opacity(0.08), lineWidth: 1))
    }
}
