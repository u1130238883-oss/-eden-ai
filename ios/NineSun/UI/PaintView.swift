import SwiftUI
import UIKit

/// 畫室：用文字描述，在手機上畫圖（完全離線）。中文的描述先請大腦翻成畫圖模型看得懂的英文。
struct PaintView: View {
    @EnvironmentObject var vm: ChatViewModel

    #if PAINT_ONLY
    static let placeholder = "用英文描述，例如：photo of an adult woman in a white dress on the beach at sunset, realistic"
    #else
    static var placeholder: String { T("想畫什麼？例如：海邊夕陽下穿白色洋裝的成年女生，寫實照片風", "What should I draw?", "¿Qué dibujo?", "Cosa disegno?") }
    #endif
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = PaintStore.shared
    @State private var prompt = ""
    @State private var status = ""
    @State private var busy = false
    @State private var progress: Double = 0
    @State private var image: UIImage?
    @State private var used = ""
    @State private var saved = false

    var body: some View {
        ZStack {
            HalftoneBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        GlitchText(text: T("畫室", "STUDIO", "ESTUDIO", "STUDIO"), size: 30)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 16, weight: .black))
                                .foregroundColor(Theme.ink).frame(width: 40, height: 32)
                                .background(Slanted(skew: 6).fill(Theme.hazard))
                        }
                    }
                    HazardStripes(height: 6)
                    if store.readyModel != nil { drawSection }
                    modelSection
                }
                .padding(16)
            }
        }
        .onDisappear { if !busy { Painter.shared.unload() } }
    }

    // MARK: - 畫

    private var drawSection: some View {
        section(T("畫一張", "Draw", "Dibujar", "Disegna") + " · DRAW") {
            TextField(Self.placeholder,
                      text: $prompt, axis: .vertical)
                .lineLimit(2...6)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.paper)
                .padding(10)
                .background(Theme.panelHi)
            Text(T("只畫成年人，不畫真實存在的人。", "Adults only; no real people.", "Solo adultos; nada de personas reales.", "Solo adulti; niente persone reali."))
                .font(.system(size: 11, weight: .medium)).foregroundColor(Theme.dim)
            HStack {
                if busy {
                    button(T("停止", "Stop", "Parar", "Stop"), color: Theme.neonPink) {
                        Painter.shared.cancel()
                        #if !PAINT_ONLY
                        LocalBrain.shared.cancel()
                        #endif
                    }
                } else {
                    button(T("開始畫", "Draw", "Dibujar", "Disegna")) { draw() }
                        .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Spacer()
                if let m = store.readyModel {
                    Text(m.name).font(Theme.hud(11)).foregroundColor(Theme.dim)
                }
            }
            if busy {
                ProgressView(value: progress).tint(Theme.hazard)
            }
            if !status.isEmpty {
                Text(status).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.paper)
            }
            if let image {
                Image(uiImage: image).resizable().scaledToFit().frame(maxWidth: .infinity)
                HStack(spacing: 12) {
                    button(saved ? T("✓ 已存到相簿", "✓ Saved", "✓ Guardada", "✓ Salvata") : T("存到相簿", "Save", "Guardar", "Salva")) {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        saved = true
                    }
                    ShareLink(item: Image(uiImage: image), preview: SharePreview("NineSun", image: Image(uiImage: image))) {
                        Text(T("分享", "Share", "Compartir", "Condividi")).font(.system(size: 14, weight: .black))
                            .foregroundColor(Theme.paper)
                            .padding(.horizontal, 18).padding(.vertical, 8)
                            .background(Slanted(skew: 7).fill(Theme.panelHi))
                    }
                }
                if !used.isEmpty {
                    Text(used).font(Theme.hud(10)).foregroundColor(Theme.dim).textSelection(.enabled)
                }
            }
        }
    }

    private func draw() {
        guard let m = store.readyModel, let url = store.resources(m) else { return }
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if Painter.crossesLine(text) { status = Painter.Failure.crossesLine.description; return }
        busy = true; saved = false; progress = 0
        let adult = vm.adultMode
        #if PAINT_ONLY
        // 測試版沒有大腦：直接用輸入的描述（要用英文）
        paint(text, url: url, gpu: m.gpu, adult: adult)
        #else
        // 有中文：先請大腦翻成英文的畫圖描述（畫圖模型只看得懂英文）
        let needsEnglish = text.unicodeScalars.contains { $0.value >= 0x3400 && $0.value <= 0x9FFF }
        if needsEnglish, let brain = ModelStore.shared.readyModel {
            status = T("把描述翻成英文…", "Translating…", "Traduciendo…", "Traduzione…")
            let system = "You write prompts for the Stable Diffusion image model. Turn the user's request into one line of comma-separated English tags: subject, appearance, clothing, pose, setting, lighting, style. All people are adults. At most 60 words. Output only the prompt."
            LocalBrain.shared.ask(modelPath: ModelStore.shared.path(brain).path, system: system, history: [], user: text, mode: .chat, lang: "en",
                                  onText: { _ in }, done: { result in
                var english = text
                if case .success(let r) = result {
                    let line = r.text.split(separator: "\n").first.map(String.init) ?? ""
                    let clean = line.trimmingCharacters(in: CharacterSet(charactersIn: "\"' ").union(.whitespaces))
                    if !clean.isEmpty { english = clean }
                }
                DispatchQueue.main.async { paint(english, url: url, gpu: m.gpu, adult: adult) }
            })
        } else {
            paint(text, url: url, gpu: m.gpu, adult: adult)
        }
        #endif
    }

    private func paint(_ english: String, url: URL, gpu: Bool, adult: Bool) {
        used = english
        if Painter.crossesLine(english) { status = Painter.Failure.crossesLine.description; busy = false; return }
        status = T("準備畫圖（第一次要讀模型，大約半分鐘）…", "Loading the model…", "Cargando el modelo…", "Carico il modello…")
        Painter.shared.paint(modelURL: url, gpu: gpu, prompt: english, adult: adult, onStep: { step, total in
            DispatchQueue.main.async {
                progress = Double(step) / Double(max(1, total))
                status = T("畫圖中 \(step)/\(total)", "Drawing \(step)/\(total)", "Dibujando \(step)/\(total)", "Disegno \(step)/\(total)")
            }
        }, done: { result in
            DispatchQueue.main.async {
                busy = false
                switch result {
                case .success(let cg):
                    image = UIImage(cgImage: cg)
                    status = ""
                case .failure(let e):
                    status = "\(e)"
                }
            }
        })
    }

    // MARK: - 模型

    private var modelSection: some View {
        section(T("畫圖模型", "Image models", "Modelos de imagen", "Modelli di immagine") + " · MODELS") {
            ForEach(PaintStore.models) { m in modelRow(m) }
        }
    }

    @ViewBuilder private func modelRow(_ m: PaintStore.Model) -> some View {
        let st = store.states[m.id] ?? .absent
        let chosen = store.selectedID == m.id
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text((chosen ? "● " : "○ ") + m.name).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.paper)
                Spacer()
                Text(PaintStore.gb(m.bytes)).font(Theme.hud(12)).foregroundColor(Theme.dim)
            }
            switch st {
            case .absent:
                button(T("下載", "Download", "Descargar", "Scarica")) { store.selectedID = m.id; store.download(m) }
            case .downloading(let done, let total):
                ProgressView(value: total > 0 ? Double(done) / Double(total) : 0).tint(Theme.hazard)
                HStack {
                    Text("\(PaintStore.gb(done)) / \(PaintStore.gb(total))").font(Theme.hud(11)).foregroundColor(Theme.paper)
                    Spacer()
                    button(T("取消", "Cancel", "Cancelar", "Annulla"), color: Theme.panelHi) { store.cancel(m) }
                }
            case .unzipping:
                Text(T("解壓縮中…", "Unpacking…", "Descomprimiendo…", "Estrazione…")).font(.system(size: 12, weight: .medium)).foregroundColor(Theme.paper)
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

    private func button(_ t: String, color: Color = Theme.hazard, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(size: 14, weight: .black))
                .foregroundColor(color == Theme.panelHi ? Theme.paper : Theme.ink)
                .padding(.horizontal, 18).padding(.vertical, 8)
                .background(Slanted(skew: 7).fill(color))
        }
    }
}
