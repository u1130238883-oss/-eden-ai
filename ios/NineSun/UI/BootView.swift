import SwiftUI

/// 開機畫面：CRT 開機 + 故障字 + 載入條。
struct BootView: View {
    var error: String? = nil
    @State private var progress: CGFloat = 0
    @State private var lines: [String] = []

    private let script = [
        "> POWER ON ............ OK",
        "> NINE & TWELVE CORE .. OK",
        "> PALACE PERCEPTION ... OK",
        "> TRANSFORMER x4 ...... OK",
        "> BAZI / ZIWEI / I-CHING OK",
        "> RULES · EVOLUTION ... OK",
        "> SIGNAL LOCKED",
    ]

    var body: some View {
        ZStack {
            HalftoneBackground()
            VStack(spacing: 0) {
                HazardStripes(height: 12)
                Spacer()
                TVAvatar(mood: error == nil ? .thinking : .idle, size: 120)
                    .padding(.bottom, 26)
                GlitchText(text: "NINESUN", size: 46)
                Text("NINE & TWELVE // " + T("九型十二宮", "NINE TYPES · TWELVE PALACES", "NUEVE TIPOS · DOCE PALACIOS", "NOVE TIPI · DODICI PALAZZI"))
                    .font(Theme.hud(12))
                    .foregroundColor(Theme.hazard)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(lines, id: \.self) { l in
                        Text(l).font(Theme.hud(11)).foregroundColor(Theme.signal.opacity(0.85))
                    }
                }
                .frame(width: 250, height: 130, alignment: .topLeading)
                .padding(.top, 28)

                ZStack(alignment: .leading) {
                    Slanted(skew: 6).fill(Theme.panelHi).frame(width: 250, height: 12)
                    Slanted(skew: 6).fill(Theme.hazard).frame(width: 250 * progress, height: 12)
                }
                .padding(.top, 8)

                if let error {
                    Text(T("訊號中斷：", "Signal lost: ", "Señal perdida: ", "Segnale perso: ") + "\(error)")
                        .font(Theme.hud(11))
                        .foregroundColor(Theme.neonPink)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                Spacer()
                Text("ON-DEVICE AI · NO NETWORK")
                    .font(Theme.hud(10))
                    .foregroundColor(Theme.dim)
                    .padding(.bottom, 10)
                HazardStripes(height: 12)
            }
            .ignoresSafeArea(edges: .horizontal)
        }
        .onAppear {
            for (i, l) in script.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 * Double(i)) {
                    lines.append(l)
                    withAnimation(.easeOut(duration: 0.2)) { progress = CGFloat(i + 1) / CGFloat(script.count) }
                }
            }
        }
    }
}
