import SwiftUI

/// NineSun 的形象：一台會眨眼的復古 CRT 電視（原創角色）。
struct TVAvatar: View {
    enum Mood { case idle, thinking, talking }
    var mood: Mood = .idle
    var size: CGFloat = 56

    @State private var blink = false
    @State private var phase: CGFloat = 0

    var body: some View {
        let s = size
        ZStack {
            // 天線
            Path { p in
                p.move(to: CGPoint(x: s * 0.42, y: s * 0.18))
                p.addLine(to: CGPoint(x: s * 0.26, y: 0))
                p.move(to: CGPoint(x: s * 0.58, y: s * 0.18))
                p.addLine(to: CGPoint(x: s * 0.78, y: s * 0.02))
            }
            .stroke(Theme.paper, style: StrokeStyle(lineWidth: s * 0.04, lineCap: .round))
            Circle().fill(Theme.neonPink).frame(width: s * 0.1).position(x: s * 0.78, y: s * 0.03)

            // 機身
            RoundedRectangle(cornerRadius: s * 0.12)
                .fill(Theme.hazard)
                .frame(width: s, height: s * 0.78)
                .position(x: s / 2, y: s * 0.58)
            RoundedRectangle(cornerRadius: s * 0.12)
                .stroke(Theme.ink, lineWidth: s * 0.05)
                .frame(width: s, height: s * 0.78)
                .position(x: s / 2, y: s * 0.58)

            // 螢幕
            RoundedRectangle(cornerRadius: s * 0.1)
                .fill(Theme.ink)
                .frame(width: s * 0.7, height: s * 0.54)
                .position(x: s * 0.42, y: s * 0.58)
            screenFace
                .frame(width: s * 0.7, height: s * 0.54)
                .clipShape(RoundedRectangle(cornerRadius: s * 0.1))
                .position(x: s * 0.42, y: s * 0.58)

            // 旋鈕
            Circle().fill(Theme.ink).frame(width: s * 0.1).position(x: s * 0.88, y: s * 0.46)
            Circle().fill(Theme.ink).frame(width: s * 0.1).position(x: s * 0.88, y: s * 0.66)
        }
        .frame(width: s, height: s)
        .onReceive(Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()) { _ in
            phase += 1
            if Int(phase) % 40 == 0 { blink = true }
            if Int(phase) % 40 == 2 { blink = false }
        }
    }

    private var screenFace: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                // 掃描線
                VStack(spacing: 2) {
                    ForEach(0..<Int(h / 3), id: \.self) { _ in
                        Rectangle().fill(Theme.signal.opacity(0.07)).frame(height: 1)
                    }
                }
                let eyeH = blink ? h * 0.05 : (mood == .thinking ? h * 0.14 : h * 0.3)
                HStack(spacing: w * 0.18) {
                    Capsule().fill(Theme.signal).frame(width: w * 0.14, height: eyeH)
                    Capsule().fill(Theme.signal).frame(width: w * 0.14, height: eyeH)
                }
                .shadow(color: Theme.signal, radius: 4)
                .offset(y: mood == .thinking ? -h * 0.08 : -h * 0.05)

                if mood == .talking {
                    Capsule().fill(Theme.signal)
                        .frame(width: w * 0.22, height: h * (0.06 + 0.08 * abs(sin(phase * 0.9))))
                        .offset(y: h * 0.25)
                } else if mood == .thinking {
                    HStack(spacing: 3) {
                        ForEach(0..<3) { i in
                            Circle().fill(Theme.signal.opacity(Int(phase / 3) % 3 == i ? 1 : 0.3))
                                .frame(width: w * 0.07)
                        }
                    }
                    .offset(y: h * 0.25)
                }
            }
            .frame(width: w, height: h)
        }
    }
}
