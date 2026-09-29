import EchoCore
import SwiftUI

/// 資料庫：六十四卦、八卦、天干地支、五行、十神、紫微星曜、四化、九型十二宮…
struct KnowledgeView: View {
    @EnvironmentObject var vm: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category: String?
    @State private var open: String?

    private var results: [KnowledgeBase.Entry] {
        guard let kb = vm.knowledge else { return [] }
        let base = query.isEmpty ? kb.entries : kb.search(query, limit: 60).map(\.entry)
        return category.map { c in base.filter { $0.cat == c } } ?? base
    }

    var body: some View {
        ZStack {
            HalftoneBackground()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    GlitchText(text: T("資料庫", "LIBRARY", "BIBLIOTECA", "BIBLIOTECA"), size: 30)
                    Spacer()
                    Text("\(vm.knowledge?.entries.count ?? 0) " + T("條", "entries", "entradas", "voci")).font(Theme.hud(11)).foregroundColor(Theme.dim)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .black))
                            .foregroundColor(Theme.ink).frame(width: 40, height: 32)
                            .background(Slanted(skew: 6).fill(Theme.hazard))
                    }
                }
                HazardStripes(height: 6)
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(Theme.hazard)
                    TextField("", text: $query, prompt: Text(T("搜尋：泰卦、七殺、化忌、6宮、乙木…", "Search: Peace, Seven Killings, palace 6, Yi Wood…", "Buscar: Paz, Siete Muertes, palacio 6, Madera Yi…", "Cerca: Pace, Sette Uccisioni, palazzo 6, Legno Yi…")).foregroundColor(Theme.dim))
                        .foregroundColor(Theme.paper)
                        .autocorrectionDisabled()
                }
                .padding(10)
                .background(NotchedPanel(cut: 10).fill(Theme.panel))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        chip(T("全部", "All", "Todo", "Tutto"), selected: category == nil) { category = nil }
                        ForEach(vm.knowledge?.categories ?? [], id: \.self) { c in
                            chip(c, selected: category == c) { category = c }
                        }
                    }
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(results) { e in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(e.title).font(.system(size: 15, weight: .black)).foregroundColor(Theme.paper)
                                    Spacer()
                                    Text(e.cat).font(Theme.hud(9)).foregroundColor(Theme.dim)
                                }
                                if open == e.title {
                                    Text(e.body).font(.system(size: 14, weight: .medium)).foregroundColor(Theme.paper.opacity(0.85))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .textSelection(.enabled)
                                    Button(T("問 NineSun ▶", "Ask NineSun ▶", "Pregunta a NineSun ▶", "Chiedi a NineSun ▶")) {
                                        vm.send(vm.language == .zh ? "\(e.aliases.first ?? e.title)是什麼"
                                                : T("", "what is ", "qué es ", "cos'è ") + (e.aliases.first ?? e.title))
                                        dismiss()
                                    }
                                    .font(Theme.hud(11)).foregroundColor(Theme.hazard)
                                }
                            }
                            .padding(12)
                            .background(NotchedPanel(cut: 10).fill(open == e.title ? Theme.panelHi : Theme.panel))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) { open = open == e.title ? nil : e.title }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .preferredColorScheme(.dark)
    }

    private func chip(_ t: String, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 12, weight: .heavy))
                .foregroundColor(selected ? Theme.ink : Theme.hazard)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Slanted(skew: 5).fill(selected ? Theme.hazard : Theme.panel))
        }
    }
}
