import SwiftUI
import Photos

// MARK: - Spec

enum GenTemplate: String, CaseIterable, Identifiable {
    case poster = "海報", hazard = "警戒", burst = "爆炸", glitch = "故障", band = "訊號條", number = "大數字"
    case sticker = "貼紙", ticket = "票券", manga = "漫畫格", neon = "霓虹"
    var id: String { rawValue }
}

struct GenPalette: Identifiable, Equatable {
    let id: String
    let bg: Color, fg: Color, accent: Color, ink: Color

    static let all: [GenPalette] = [
        .init(id: "夜班", bg: Color(hex: 0x0B0B0C), fg: Color(hex: 0xF4F4F0), accent: Color(hex: 0xE8FF3A), ink: Color(hex: 0x0B0B0C)),
        .init(id: "警戒", bg: Color(hex: 0x141414), fg: Color(hex: 0xF2F2EE), accent: Color(hex: 0xFFC21A), ink: Color(hex: 0x141414)),
        .init(id: "漫畫", bg: Color(hex: 0xFF2E88), fg: Color(hex: 0x1A0B2E), accent: Color(hex: 0xFFF14A), ink: Color(hex: 0x1A0B2E)),
        .init(id: "霓虹", bg: Color(hex: 0x101018), fg: Color(hex: 0xFFFFFF), accent: Color(hex: 0x2EE6FF), ink: Color(hex: 0x101018)),
        .init(id: "青檸", bg: Color(hex: 0x0D0F08), fg: Color(hex: 0xF5FF6A), accent: Color(hex: 0xC6FF1A), ink: Color(hex: 0x0D0F08)),
        .init(id: "夕陽", bg: Color(hex: 0x1E1036), fg: Color(hex: 0xFFE8C2), accent: Color(hex: 0xFF8A3D), ink: Color(hex: 0x1E1036)),
        .init(id: "紫電", bg: Color(hex: 0x14092A), fg: Color(hex: 0xF4F0FF), accent: Color(hex: 0x9B5BFF), ink: Color(hex: 0x14092A)),
        .init(id: "紙白", bg: Color(hex: 0xEDEBE3), fg: Color(hex: 0x111111), accent: Color(hex: 0xFF3D2E), ink: Color(hex: 0xEDEBE3)),
        .init(id: "薄荷", bg: Color(hex: 0x0E1F1C), fg: Color(hex: 0xEFFFF8), accent: Color(hex: 0x3DFFB0), ink: Color(hex: 0x0E1F1C)),
        .init(id: "櫻桃", bg: Color(hex: 0x2A0712), fg: Color(hex: 0xFFE9EF), accent: Color(hex: 0xFF3D6E), ink: Color(hex: 0x2A0712)),
        .init(id: "電藍", bg: Color(hex: 0x0A1240), fg: Color(hex: 0xF2F5FF), accent: Color(hex: 0x3D6BFF), ink: Color(hex: 0x0A1240)),
        .init(id: "芥末", bg: Color(hex: 0xF2C230), fg: Color(hex: 0x1B1B1B), accent: Color(hex: 0x1B1B1B), ink: Color(hex: 0xF2C230)),
    ]
}

struct GenSpec: Equatable {
    var template: GenTemplate = .poster
    var paletteID: String = "夜班"
    var line1 = "NIGHT"
    var line2 = "SHIFT"
    var sub = "SECTOR 09 // 02:47"
    var halftone = true
    var tape = true
    var scan = false
    var grain = true
    var tilt: Double = -8
    var seed: UInt64 = 9

    var palette: GenPalette { GenPalette.all.first { $0.id == paletteID } ?? GenPalette.all[0] }

    static let words: [(String, String)] = [
        ("NIGHT", "SHIFT"), ("NO", "SIGNAL"), ("STAY", "ODD"), ("KEEP", "OUT"), ("LEVEL", "UP"),
        ("GO", "GO!!"), ("HIGH", "MOOD"), ("ZONE", "09"), ("LAST", "TRAIN"), ("DROP", "26"),
        ("OFF", "LINE"), ("BASS", "BOOST"), ("NEW", "WAVE"), ("DEAD", "END"), ("HOT", "WIRE"),
        ("TAPE", "07"), ("STAND", "BY"), ("FULL", "SPEED"), ("LOW", "KEY"), ("WILD", "CARD"),
    ]
    static let subs = [
        "SECTOR 09 // 02:47", "FREQ 09.47 MHz · STRONG", "CH 11 · LIVE FEED", "DO NOT DISTURB_",
        "FW 26 / DROP", "ERR 0x09 · RECONNECTING", "LAST TRAIN 00:42", "PLAYER 01 · STAGE 09",
        "ALL ZONES · ACCESS", "REWIND · PLAY · REPEAT",
    ]

    static func random() -> GenSpec {
        var s = GenSpec()
        s.template = GenTemplate.allCases.randomElement()!
        s.paletteID = GenPalette.all.randomElement()!.id
        let w = words.randomElement()!
        s.line1 = w.0
        s.line2 = w.1
        s.sub = subs.randomElement()!
        s.halftone = Bool.random()
        s.tape = Bool.random()
        s.scan = Int.random(in: 0..<3) == 0
        s.grain = Int.random(in: 0..<4) != 0
        s.tilt = Double(Int.random(in: -12...12))
        s.seed = UInt64.random(in: 1...999_999)
        return s
    }
}

// MARK: - The artwork (fixed 390×844 pt canvas → 1170×2532 px at @3x, iPhone 16e native)

struct WallArt: View {
    let spec: GenSpec
    private var p: GenPalette { spec.palette }

    var body: some View {
        ZStack(alignment: .topLeading) {
            p.bg
            switch spec.template {
            case .poster: poster
            case .hazard: hazard
            case .burst: burst
            case .glitch: glitch
            case .band: band
            case .number: number
            case .sticker: sticker
            case .ticket: ticket
            case .manga: manga
            case .neon: neon
            }
            if spec.scan { Scanlines() }
            if spec.grain { Grain(seed: spec.seed, light: p.fg) }
        }
        .frame(width: 390, height: 844)
        .clipped()
    }

    // helpers
    private func big(_ s: String, _ size: CGFloat, _ color: Color, width: CGFloat = 350) -> some View {
        Text(s.uppercased()).font(.display(size)).foregroundStyle(color)
            .lineLimit(1).minimumScaleFactor(0.25)
            .frame(width: width, alignment: .leading)
    }
    private func outline(_ s: String, _ size: CGFloat, stroke: Color, fill: Color, width: CGFloat = 350, w: CGFloat = 2) -> some View {
        ZStack(alignment: .leading) {
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) * .pi / 4
                big(s, size, stroke, width: width).offset(x: cos(a) * w, y: sin(a) * w)
            }
            big(s, size, fill, width: width)
        }
    }
    private func mono(_ s: String, _ size: CGFloat = 11, _ c: Color) -> some View {
        Text(s).font(.mono(size)).tracking(1).foregroundStyle(c)
    }
    private func tapeStripe(y: CGFloat, color: Color, back: Color) -> some View {
        ZStack { back; HazardStripe(color: color, band: 18) }
            .frame(width: 520, height: 34)
            .rotationEffect(.degrees(spec.tilt))
            .offset(x: -65, y: y)
    }
    private func dots(_ c: Color, x: CGFloat, y: CGFloat, d: CGFloat, op: Double = 0.35) -> some View {
        Halftone(color: c, spacing: 10, radius: 1.6)
            .frame(width: d, height: d).clipShape(Circle()).opacity(op)
            .offset(x: x, y: y)
    }

    // 01 poster
    private var poster: some View {
        ZStack(alignment: .topLeading) {
            if spec.halftone { dots(p.accent, x: 150, y: 120, d: 300) }
            Rectangle().stroke(p.accent, lineWidth: 3).frame(width: 64, height: 64)
                .rotationEffect(.degrees(45)).offset(x: 34, y: 300)
            if spec.tape { tapeStripe(y: 470, color: p.accent, back: p.bg) }
            VStack(alignment: .leading, spacing: -22) {
                big(spec.line1, 132, p.accent)
                outline(spec.line2, 132, stroke: p.fg, fill: p.bg)
            }
            .offset(x: 22, y: 520)
            HStack {
                mono(spec.sub, 11, p.fg)
                Spacer()
                mono("● ON AIR", 11, p.accent)
            }
            .frame(width: 342).offset(x: 24, y: 790)
        }
    }

    // 02 hazard
    private var hazard: some View {
        ZStack(alignment: .topLeading) {
            HazardStripe(color: p.accent, band: 28)
            if spec.halftone { dots(p.bg, x: -80, y: 560, d: 360, op: 0.25) }
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 92, weight: .heavy)).foregroundStyle(p.accent)
                Text(spec.line1.uppercased()).font(.display(96)).foregroundStyle(p.accent)
                    .lineLimit(1).minimumScaleFactor(0.3)
                Text(spec.line2.uppercased()).font(.display(96)).foregroundStyle(p.fg)
                    .lineLimit(1).minimumScaleFactor(0.3).padding(.top, -24)
                mono(spec.sub, 12, p.accent)
            }
            .padding(20)
            .frame(width: 330, height: 420)
            .background(p.bg)
            .overlay(Rectangle().stroke(p.accent, lineWidth: 6))
            .offset(x: 30, y: 230)
            if spec.tape {
                cautionTape("CAUTION · CAUTION · CAUTION · CAUTION", y: 690, angle: abs(spec.tilt) + 2)
                cautionTape("DO NOT CROSS · DO NOT CROSS", y: 160, angle: -abs(spec.tilt))
            }
        }
    }
    private func cautionTape(_ t: String, y: CGFloat, angle: Double) -> some View {
        Text(t).font(.display(28)).tracking(6).foregroundStyle(p.ink).lineLimit(1)
            .frame(width: 520, height: 46).background(p.accent)
            .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 6)
            .rotationEffect(.degrees(angle)).offset(x: -65, y: y)
    }

    // 03 burst
    private var burst: some View {
        ZStack(alignment: .topLeading) {
            if spec.halftone {
                Halftone(color: p.accent.opacity(0.5), spacing: 12, radius: 2.4)
                Halftone(color: p.fg.opacity(0.5), spacing: 9, radius: 2).frame(height: 260).offset(y: 584)
            }
            Star(points: 9).fill(p.accent)
                .overlay(Star(points: 9).stroke(p.fg, style: StrokeStyle(lineWidth: 8, lineJoin: .round)))
                .frame(width: 360, height: 360).rotationEffect(.degrees(spec.tilt)).offset(x: 15, y: 250)
            Text(spec.line1.uppercased()).font(.display(112)).foregroundStyle(p.fg)
                .lineLimit(1).minimumScaleFactor(0.3)
                .frame(width: 280).rotationEffect(.degrees(-6)).offset(x: 55, y: 360)
            if spec.tape {
                Text("\(spec.line2.uppercased()) ▸").font(.display(30)).foregroundStyle(p.fg)
                    .padding(.horizontal, 18).padding(.vertical, 8)
                    .background(Color(hex: 0xF7F7F2))
                    .overlay(Rectangle().stroke(p.fg, lineWidth: 5))
                    .shadow(color: p.fg, radius: 0, x: 8, y: 8)
                    .rotationEffect(.degrees(3)).offset(x: 30, y: 690)
            }
            Text("#9").font(.display(30)).foregroundStyle(p.accent)
                .frame(width: 70, height: 70).background(Circle().fill(p.fg)).offset(x: 294, y: 170)
        }
    }

    // 04 glitch
    private var glitch: some View {
        ZStack(alignment: .topLeading) {
            Scanlines()
            if spec.halftone { dots(p.accent, x: 200, y: 80, d: 260, op: 0.18) }
            VStack(alignment: .leading, spacing: -6) {
                rgb(spec.line1)
                rgb(spec.line2)
            }
            .offset(x: 20, y: 400)
            Rectangle().fill(p.bg).frame(width: 390, height: 10).offset(y: 470)
            Rectangle().fill(p.accent).frame(width: 270, height: 6).offset(x: 120, y: 560)
            Rectangle().fill(Theme.cyan).frame(width: 160, height: 3).offset(y: 380)
            if spec.tape { Rectangle().fill(Theme.hot).frame(width: 90, height: 3).offset(x: 260, y: 300) }
            VStack(alignment: .leading, spacing: 4) {
                mono("> signal lost", 12, p.fg.opacity(0.55))
                mono("> reconnecting...", 12, p.fg.opacity(0.55))
                mono("> \(spec.sub.lowercased())_", 12, p.accent)
            }
            .offset(x: 24, y: 610)
            mono("ERR 0x09", 11, p.fg.opacity(0.55)).offset(x: 300, y: 790)
        }
    }
    private func rgb(_ s: String) -> some View {
        ZStack(alignment: .leading) {
            big(s, 80, Color(hex: 0xFF2E4D).opacity(0.9)).offset(x: 4)
            big(s, 80, Theme.cyan.opacity(0.9)).offset(x: -4)
            big(s, 80, p.fg)
        }
    }

    // 05 band
    private var band: some View {
        ZStack(alignment: .topLeading) {
            p.accent
            if spec.halftone { dots(p.ink, x: -120, y: 520, d: 420, op: 0.22) }
            p.ink.frame(width: 390, height: 230).offset(y: 300)
            big(spec.line1, 150, p.accent, width: 350).frame(height: 230).offset(x: 20, y: 300)
            mono("\(spec.line2.uppercased()) · \(spec.sub)", 13, p.ink).offset(x: 24, y: 560)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<4, id: \.self) { i in p.ink.frame(width: 16, height: CGFloat(20 + i * 16)) }
            }
            .offset(x: 24, y: 600)
            if spec.tape {
                ZStack { p.ink; HazardStripe(color: p.accent, band: 14) }
                    .frame(width: 390, height: 28).offset(y: 120)
            }
            mono("CH—11", 11, p.ink).offset(x: 316, y: 790)
        }
    }

    // 06 number
    private var number: some View {
        let digits = spec.line2.filter(\.isNumber)
        let n = digits.isEmpty ? "09" : String(digits.prefix(2))
        return ZStack(alignment: .topLeading) {
            p.accent.opacity(0.18)
            if spec.halftone {
                Canvas { ctx, size in
                    var x: CGFloat = 0
                    while x < size.width {
                        ctx.fill(Path(CGRect(x: x, y: 0, width: 2, height: size.height)), with: .color(p.fg.opacity(0.08)))
                        x += 14
                    }
                }
            }
            outline(n, 400, stroke: p.fg, fill: .clear, width: 400, w: 3).offset(x: -10, y: 230)
            big(n, 400, p.accent.opacity(0.9), width: 400).offset(x: 6, y: 246)
            Text(spec.line1.uppercased()).font(.mono(12)).tracking(2).foregroundStyle(p.bg)
                .padding(.horizontal, 12).padding(.vertical, 6).background(p.fg).offset(x: 24, y: 200)
            if spec.tape { tapeStripe(y: 700, color: p.accent, back: p.bg) }
            HStack { mono(spec.sub, 11, p.fg); Spacer(); mono("EST. 26", 11, p.fg) }
                .frame(width: 342).offset(x: 24, y: 790)
        }
    }

    // 07 sticker bomb
    private var sticker: some View {
        var r = SeededRNG(seed: spec.seed)
        var jit: [Double] = []
        for _ in 0..<6 { jit.append(Double(Int.random(in: -6...6, using: &r))) }
        let t = spec.tilt / 2
        func rot(_ i: Int, _ base: Double) -> Double { base + jit[i] + t }
        return ZStack(alignment: .topLeading) {
            if spec.halftone { Halftone(color: p.fg.opacity(0.10), spacing: 14, radius: 1.6) }
            // big label
            Text(spec.line1.uppercased()).font(.display(76)).foregroundStyle(p.ink)
                .lineLimit(1).minimumScaleFactor(0.3).frame(width: 290)
                .padding(.horizontal, 18).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 14).fill(p.accent))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.fg, lineWidth: 5))
                .shadow(color: .black.opacity(0.35), radius: 0, x: 6, y: 8)
                .rotationEffect(.degrees(rot(0, -7))).offset(x: 24, y: 300)
            // round badge
            VStack(spacing: -4) {
                Text("100%").font(.display(34))
                Text("LEGIT").font(.display(22))
            }
            .foregroundStyle(p.fg)
            .frame(width: 128, height: 128)
            .background(Circle().fill(Theme.hot))
            .overlay(Circle().stroke(p.fg, lineWidth: 5))
            .rotationEffect(.degrees(rot(1, 14))).offset(x: 236, y: 410)
            // capsule
            Text(spec.line2.uppercased()).font(.display(54)).foregroundStyle(p.bg)
                .lineLimit(1).minimumScaleFactor(0.3).frame(maxWidth: 250)
                .padding(.horizontal, 26).padding(.vertical, 8)
                .background(Capsule().fill(p.fg))
                .overlay(Capsule().stroke(p.accent, lineWidth: 5))
                .shadow(color: .black.opacity(0.35), radius: 0, x: 5, y: 7)
                .rotationEffect(.degrees(rot(2, 5))).offset(x: 36, y: 520)
            // smiley tile
            ZStack {
                RoundedRectangle(cornerRadius: 26).fill(p.accent)
                Image(systemName: "face.smiling").font(.system(size: 76, weight: .bold)).foregroundStyle(p.ink)
            }
            .frame(width: 140, height: 140)
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(p.fg, lineWidth: 5))
            .rotationEffect(.degrees(rot(3, -12))).offset(x: 40, y: 620)
            // dashed label
            if spec.tape {
                Text(spec.sub.uppercased()).font(.mono(12)).foregroundStyle(p.ink)
                    .padding(10).frame(width: 170, alignment: .leading)
                    .background(p.fg)
                    .overlay(Rectangle().stroke(p.ink, style: StrokeStyle(lineWidth: 2, dash: [6, 4])).padding(4))
                    .rotationEffect(.degrees(rot(4, -4))).offset(x: 196, y: 650)
            }
            Star(points: 5).fill(Theme.cyan).overlay(Star(points: 5).stroke(p.fg, lineWidth: 4))
                .frame(width: 70, height: 70).rotationEffect(.degrees(rot(5, 10))).offset(x: 300, y: 270)
        }
    }

    // 08 ticket
    private var ticket: some View {
        var r = SeededRNG(seed: spec.seed)
        var bars: [CGFloat] = []
        for _ in 0..<34 { bars.append(CGFloat(Int.random(in: 1...4, using: &r))) }
        return ZStack(alignment: .topLeading) {
            if spec.halftone { dots(p.accent, x: -60, y: 120, d: 340, op: 0.25) }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18).fill(p.fg)
                // notches
                Circle().fill(p.bg).frame(width: 40, height: 40).offset(x: -20, y: 278)
                Circle().fill(p.bg).frame(width: 40, height: 40).offset(x: 300, y: 278)
                Path { $0.move(to: CGPoint(x: 26, y: 298)); $0.addLine(to: CGPoint(x: 294, y: 298)) }
                    .stroke(p.bg, style: StrokeStyle(lineWidth: 3, dash: [8, 7]))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("ADMIT ONE").font(.mono(13)).tracking(3)
                        Spacer()
                        Text("No.\(spec.seed % 100000)").font(.mono(12))
                    }
                    .foregroundStyle(p.bg.opacity(0.8))
                    Text(spec.line1.uppercased()).font(.display(88)).foregroundStyle(p.bg)
                        .lineLimit(1).minimumScaleFactor(0.3).padding(.top, 8)
                    Text(spec.line2.uppercased()).font(.display(88)).foregroundStyle(p.accent == p.fg ? p.bg : p.accent)
                        .lineLimit(1).minimumScaleFactor(0.3).padding(.top, -26)
                }
                .padding(22).frame(width: 320, alignment: .leading)
                VStack(alignment: .leading, spacing: 10) {
                    Text(spec.sub.uppercased()).font(.mono(12)).foregroundStyle(p.bg)
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(Array(bars.enumerated()), id: \.offset) { _, w in
                            Rectangle().fill(p.bg).frame(width: w, height: 54)
                        }
                    }
                    Text("ZONE 09 · ROW B · SEAT \(spec.seed % 40 + 1)").font(.mono(11)).foregroundStyle(p.bg.opacity(0.7))
                }
                .padding(.horizontal, 24).offset(y: 318)
            }
            .frame(width: 320, height: 430)
            .shadow(color: p.accent, radius: 0, x: 10, y: 10)
            .rotationEffect(.degrees(spec.tilt / 2))
            .offset(x: 35, y: 290)
            if spec.tape {
                Rectangle().fill(p.accent.opacity(0.85)).frame(width: 130, height: 38)
                    .rotationEffect(.degrees(-28)).offset(x: 10, y: 290)
            }
        }
    }

    // 09 manga speed lines
    private var manga: some View {
        var r = SeededRNG(seed: spec.seed)
        var angles: [(CGFloat, CGFloat)] = []
        for _ in 0..<90 { angles.append((CGFloat.random(in: 0..<(2 * .pi), using: &r), CGFloat.random(in: 1...5, using: &r))) }
        return ZStack(alignment: .topLeading) {
            p.fg
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: 470)
                for (a, w) in angles {
                    var path = Path()
                    let inner: CGFloat = 170
                    path.move(to: CGPoint(x: c.x + cos(a) * inner, y: c.y + sin(a) * inner))
                    path.addLine(to: CGPoint(x: c.x + cos(a + 0.012 * w) * 900, y: c.y + sin(a + 0.012 * w) * 900))
                    path.addLine(to: CGPoint(x: c.x + cos(a - 0.012 * w) * 900, y: c.y + sin(a - 0.012 * w) * 900))
                    path.closeSubpath()
                    ctx.fill(path, with: .color(p.bg))
                }
            }
            if spec.halftone {
                Halftone(color: p.bg.opacity(0.35), spacing: 9, radius: 1.8).frame(height: 200).offset(y: 644)
            }
            outline(spec.line1, 120, stroke: p.bg, fill: p.accent, width: 340, w: 4)
                .rotationEffect(.degrees(spec.tilt)).offset(x: 25, y: 380)
            // speech bubble
            ZStack(alignment: .bottomLeading) {
                Ellipse().fill(Color.white).overlay(Ellipse().stroke(p.bg, lineWidth: 5))
                Path { pth in
                    pth.move(to: CGPoint(x: 60, y: 96)); pth.addLine(to: CGPoint(x: 30, y: 140)); pth.addLine(to: CGPoint(x: 100, y: 104))
                }
                .fill(Color.white)
                Text(spec.line2.uppercased()).font(.display(46)).foregroundStyle(Color(hex: 0x111111))
                    .lineLimit(1).minimumScaleFactor(0.3).frame(width: 190, height: 110)
            }
            .frame(width: 220, height: 120).offset(x: 140, y: 560)
            if spec.tape {
                Text(spec.sub.uppercased()).font(.display(22)).foregroundStyle(p.fg)
                    .padding(.horizontal, 14).padding(.vertical, 6).background(p.bg)
                    .rotationEffect(.degrees(-3)).offset(x: 22, y: 720)
            }
        }
    }

    // 10 neon sign
    private var neon: some View {
        let glow2 = Theme.hot
        return ZStack(alignment: .topLeading) {
            LinearGradient(colors: [p.bg, p.bg.opacity(0.85), .black], startPoint: .top, endPoint: .bottom)
            if spec.halftone {
                Canvas { ctx, size in
                    var y: CGFloat = 0, row = 0
                    while y < size.height {
                        var x: CGFloat = row.isMultiple(of: 2) ? 0 : -30
                        while x < size.width {
                            ctx.stroke(Path(CGRect(x: x, y: y, width: 60, height: 26)), with: .color(p.fg.opacity(0.05)), lineWidth: 1)
                            x += 60
                        }
                        y += 26; row += 1
                    }
                }
            }
            RoundedRectangle(cornerRadius: 30).stroke(p.accent, lineWidth: 5)
                .shadow(color: p.accent, radius: 6).shadow(color: p.accent, radius: 18)
                .frame(width: 330, height: 330).offset(x: 30, y: 320)
            VStack(spacing: -10) {
                Text(spec.line1.uppercased()).font(.display(96)).foregroundStyle(Color.white)
                    .lineLimit(1).minimumScaleFactor(0.3)
                    .shadow(color: p.accent, radius: 4).shadow(color: p.accent, radius: 14).shadow(color: p.accent, radius: 30)
                Text(spec.line2.uppercased()).font(.display(96)).foregroundStyle(Color.white)
                    .lineLimit(1).minimumScaleFactor(0.3)
                    .shadow(color: glow2, radius: 4).shadow(color: glow2, radius: 14).shadow(color: glow2, radius: 30)
            }
            .frame(width: 290).rotationEffect(.degrees(spec.tilt / 3)).offset(x: 50, y: 360)
            if spec.tape {
                Text("OPEN 24H").font(.mono(15)).tracking(4).foregroundStyle(Theme.cyan)
                    .shadow(color: Theme.cyan, radius: 8)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .overlay(Capsule().stroke(Theme.cyan, lineWidth: 2).shadow(color: Theme.cyan, radius: 8))
                    .offset(x: 120, y: 680)
            }
            mono(spec.sub, 11, p.fg.opacity(0.7)).offset(x: 24, y: 790)
        }
    }
}

/// Deterministic RNG so a spec always renders the same art.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E3779B97F4A7C15 | 1 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Film-grain speckle overlay.
struct Grain: View {
    let seed: UInt64
    let light: Color
    var body: some View {
        Canvas { ctx, size in
            var r = SeededRNG(seed: seed)
            for _ in 0..<2600 {
                let x = CGFloat.random(in: 0..<size.width, using: &r)
                let y = CGFloat.random(in: 0..<size.height, using: &r)
                let s = CGFloat.random(in: 0.6...1.6, using: &r)
                let dark = Bool.random(using: &r)
                ctx.fill(Path(CGRect(x: x, y: y, width: s, height: s)),
                         with: .color(dark ? Color.black.opacity(0.22) : light.opacity(0.16)))
            }
        }
        .allowsHitTesting(false)
    }
}

struct Star: Shape {
    var points: Int = 9
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let outer = min(r.width, r.height) / 2
        var p = Path()
        let n = points * 2
        for i in 0..<n {
            let rad = i.isMultiple(of: 2) ? outer : outer * (i % 4 == 1 ? 0.62 : 0.55)
            let a = Double(i) / Double(n) * 2 * .pi - .pi / 2
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rad, y: c.y + CGFloat(sin(a)) * rad)
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Generator screen

struct GeneratorView: View {
    @EnvironmentObject var toaster: Toaster
    @EnvironmentObject var center: ApplyCenter
    @State private var spec = GenSpec()
    @State private var history: [GenSpec] = []
    @State private var saving = false
    @State private var full = false
    @State private var showClock = true
    @State private var pickTarget = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WALL GENERATOR").font(.mono(11)).tracking(3).foregroundStyle(Theme.dim)
                        Text("壁紙生成器").font(.display(30)).foregroundStyle(Theme.paper)
                    }
                    Spacer()
                    Text("1170×2532").font(.mono(11)).foregroundStyle(Theme.acid)
                }

                // preview
                HStack(alignment: .top, spacing: 12) {
                    ZStack(alignment: .topLeading) {
                        WallArt(spec: spec)
                            .scaleEffect(0.48, anchor: .topLeading)
                            .frame(width: 390 * 0.48, height: 844 * 0.48, alignment: .topLeading)
                        if showClock { LockOverlay(scale: 0.48) }
                    }
                    .frame(width: 390 * 0.48, height: 844 * 0.48, alignment: .topLeading)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.paper, lineWidth: 3))
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(spec.palette.accent).offset(x: 6, y: 6))
                        .onTapGesture { withAnimation(.snappy) { showClock.toggle() } }
                        .onLongPressGesture(minimumDuration: 0.35) { full = true }
                        .accessibilityLabel("預覽，點一下切換時鐘，長按全螢幕")
                        .animation(.snappy, value: spec)

                    VStack(spacing: 10) {
                        Button {
                            Haptics.tap()
                            history.append(spec)
                            if history.count > 30 { history.removeFirst() }
                            withAnimation(.snappy) { spec = .random() }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "dice.fill").font(.system(size: 28, weight: .heavy))
                                Text("隨機骰").font(.display(20))
                            }
                            .frame(maxWidth: .infinity, minHeight: 84)
                        }
                        .buttonStyle(SlantButtonStyle())

                        HStack(spacing: 8) {
                            Button {
                                guard let last = history.popLast() else { return }
                                Haptics.tap()
                                withAnimation(.snappy) { spec = last }
                            } label: {
                                Image(systemName: "arrow.uturn.backward").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SlantButtonStyle(fill: Theme.paper, outline: true))
                            .disabled(history.isEmpty)
                            .accessibilityLabel("上一個")

                            Button {
                                Haptics.tap()
                                withAnimation(.snappy) { spec.seed = UInt64.random(in: 1...999_999) }
                            } label: {
                                Image(systemName: "sparkles").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SlantButtonStyle(fill: Theme.paper, outline: true))
                            .accessibilityLabel("換個變化")
                        }

                        Button { pickTarget = true } label: {
                            Label("一鍵套用", systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SlantButtonStyle(fill: Theme.hot))

                        Button { save() } label: {
                            Label(saving ? "保存中" : "存相簿", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SlantButtonStyle(fill: Theme.paper, outline: true))
                        .disabled(saving)

                    }
                }
                Text("點預覽切換時鐘 · 長按全螢幕 · ✦ 換個變化（同樣式、不同排列/紋理）")
                    .font(.mono(10)).foregroundStyle(Theme.dim)

                group("01", "版式") {
                    chips(GenTemplate.allCases.map { ($0.id, $0.rawValue) }, selected: spec.template.id) { id in
                        spec.template = GenTemplate(rawValue: id) ?? .poster
                    }
                }

                group("02", "配色") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(GenPalette.all) { pal in
                                Button {
                                    Haptics.tap()
                                    withAnimation(.snappy) { spec.paletteID = pal.id }
                                } label: {
                                    VStack(spacing: 4) {
                                        HStack(spacing: 0) {
                                            pal.bg; pal.accent; pal.fg
                                        }
                                        .frame(width: 54, height: 30)
                                        .clipShape(Slant(cut: 8))
                                        .overlay(Slant(cut: 8).stroke(spec.paletteID == pal.id ? Theme.acid : Theme.line, lineWidth: spec.paletteID == pal.id ? 3 : 1))
                                        Text(pal.id).font(.mono(10)).foregroundStyle(spec.paletteID == pal.id ? Theme.acid : Theme.dim)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("配色 \(pal.id)")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                group("03", "文字") {
                    field("第一行", $spec.line1)
                    field("第二行", $spec.line2)
                    field("小字", $spec.sub)
                    Text("「大數字」版式會用第二行裡的數字。").font(.mono(10)).foregroundStyle(Theme.dim)
                }

                group("04", "裝飾") {
                    toggle("網點", $spec.halftone)
                    toggle("膠帶 / 標籤", $spec.tape)
                    toggle("掃描線", $spec.scan)
                    toggle("顆粒質感", $spec.grain)
                    HStack {
                        Text("傾斜").font(.system(size: 14)).foregroundStyle(Theme.paper)
                        Slider(value: $spec.tilt, in: -15...15, step: 1).tint(Theme.acid)
                        Text("\(Int(spec.tilt))°").font(.mono(11)).foregroundStyle(Theme.acid).frame(width: 36)
                    }
                }
                Spacer(minLength: 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
        }
        .scrollDismissesKeyboard(.interactively)
        .fullScreenCover(isPresented: $full) {
            GeneratedFullView(spec: spec)
        }
        .confirmationDialog("套用生成的壁紙", isPresented: $pickTarget, titleVisibility: .visible) {
            ForEach(WallTarget.allCases) { t in
                Button(t.label) { applyGenerated(t) }
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func group<C: View>(_ code: String, _ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Tag(text: code)
                Text(title).font(.display(20)).foregroundStyle(Theme.paper)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CutPanel(cut: 14).fill(Theme.panel))
        .overlay(CutPanel(cut: 14).stroke(Theme.line, lineWidth: 1))
    }

    private func chips(_ items: [(String, String)], selected: String, _ pick: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.0) { item in
                Button {
                    Haptics.tap()
                    withAnimation(.snappy) { pick(item.0) }
                } label: {
                    Text(item.1).font(.display(17))
                        .foregroundStyle(selected == item.0 ? Theme.ink : Theme.paper)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Slant(cut: 8).fill(selected == item.0 ? Theme.acid : Theme.panel2))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.mono(11)).foregroundStyle(Theme.dim).frame(width: 48, alignment: .leading)
            TextField(label, text: text)
                .font(.display(20)).foregroundStyle(Theme.acid)
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .padding(.horizontal, 12).frame(minHeight: 44)
                .background(CutPanel(cut: 8).stroke(Theme.line, lineWidth: 1.5))
        }
    }

    private func toggle(_ label: String, _ v: Binding<Bool>) -> some View {
        Toggle(isOn: v) { Text(label).font(.system(size: 14)).foregroundStyle(Theme.paper) }
            .tint(Theme.acid)
    }

    private func applyGenerated(_ t: WallTarget) {
        guard let data = GeneratorRender.image(spec)?.pngData() else {
            toaster.show("生成失敗，請再試一次"); return
        }
        center.apply(data: data, to: t, toaster: toaster)
    }

    private func save() {
        saving = true
        guard let img = GeneratorRender.image(spec) else {
            saving = false
            toaster.show("生成失敗，請再試一次")
            return
        }
        Task {
            do {
                try await PhotoSaver.save(image: img)
                Haptics.ok()
                toaster.show("已存入相簿 1170×2532")
            } catch {
                Haptics.fail()
                toaster.show(error.localizedDescription)
            }
            saving = false
        }
    }
}

enum GeneratorRender {
    @MainActor
    static func image(_ spec: GenSpec) -> UIImage? {
        let r = ImageRenderer(content: WallArt(spec: spec).environment(\.colorScheme, .dark))
        r.scale = 3          // 390×844 pt → 1170×2532 px (iPhone 16e)
        r.isOpaque = true
        return r.uiImage
    }
}

struct GeneratedFullView: View {
    let spec: GenSpec
    @Environment(\.dismiss) private var dismiss
    @State private var lock = true

    var body: some View {
        GeometryReader { geo in
            let s = geo.size.width / 390
            ZStack {
                WallArt(spec: spec)
                    .scaleEffect(s, anchor: .topLeading)
                    .frame(width: geo.size.width, height: 844 * s, alignment: .topLeading)
                if lock { LockOverlay(scale: s) }
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
        .statusBarHidden()
        .onTapGesture { withAnimation { lock.toggle() } }
        .overlay(alignment: .bottomTrailing) {
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(SlantButtonStyle(fill: Theme.paper, outline: true))
                .padding(24)
                .accessibilityLabel("關閉")
        }
    }
}
