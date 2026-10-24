import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 手機內建的 Apple 智慧（iOS 26 的 Foundation Models，在手機上跑、不用網路、不用金鑰）：
/// NineSun 自己的引擎負責找資料、算命盤；真正「想」——讀懂問題要的是什麼、整理資料、說出自己的看法——交給它。
/// 不能用（舊手機、沒開 Apple 智慧、模型還在下載、語言不支援）時回傳 nil，照舊用 NineSun 自己的回答。
enum OnDeviceAI {
    /// 這支手機現在能不能用
    static var available: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// 為什麼不能用（給設定頁看）
    static var status: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return "可以使用：問題會交給手機內建的 Apple 智慧思考。"
            case .unavailable(let why):
                let w = String(describing: why)
                if w.contains("deviceNotEligible") { return "這支手機不支援 Apple 智慧（要 iPhone 15 Pro 以上）。" }
                if w.contains("NotEnabled") { return "還沒開啟 Apple 智慧：到「設定 → Apple 智慧與 Siri」打開。" }
                if w.contains("modelNotReady") { return "Apple 智慧的模型還在下載，好了就能用（接上 Wi-Fi、充電時比較快）。" }
                return "Apple 智慧暫時不能用。"
            @unknown default:
                return "Apple 智慧暫時不能用。"
            }
        }
        #endif
        return "要 iOS 26 以上才能用 Apple 智慧。"
    }

    /// NineSun 的個性和思考方式（這段是給模型的指示）
    static func instructions(persona: String) -> String {
        """
        你是 NineSun——一台會發光的小電視機器人夥伴，有自己的個性和想法，不是客服式的助理。用繁體中文（台灣用語）回答。
        回答前先想清楚：對方真正想知道的是什麼？（例如問「格林童話有什麼故事」，是要你說出有哪些故事、各在講什麼，不是說有幾個；問「X在講什麼」，是要故事和它想表達的道理。）
        回答方式：先直接回答，再說明重點，最後用「我覺得…」說出你自己的看法或建議——要有立場，不要只說「各有說法」。可以用生活中的比喻。
        只根據提供的資料和你確定知道的事實；資料裡沒有、你也不確定的，就老實說不確定，絕對不要編造數字、日期、人名或出處。
        網路資料可能有雜訊（廣告、讀者閒聊、別部作品），自己判斷哪些有用。不要用 Markdown 符號（#、**）。
        \(persona)
        """
    }

    /// 問它：system＝指示，prompt＝問題和資料。失敗（太長、被安全機制擋、語言不支援）回傳 nil
    static func respond(instructions: String, prompt: String, maxTokens: Int = 700) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard available else { return nil }
            let session = LanguageModelSession(instructions: instructions)
            do {
                let r = try await session.respond(to: prompt, options: GenerationOptions(temperature: 0.6, maximumResponseTokens: maxTokens))
                let t = r.content.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    /// 上網查到的資料交給它想：先讀懂問題，再根據資料回答、說出自己的看法。
    /// 模型一次能讀的字有限（大約 4000 個 token，包含它要寫的回答），資料太長就砍半再試一次
    static func answer(question: String, evidence: [String], notes: String, persona: String) async -> String? {
        var budget = 1200
        for _ in 0..<2 {
            var used = 0
            var lines: [String] = []
            for (i, e) in evidence.enumerated() where used + e.count <= budget {
                lines.append("\(i + 1). \(e)")
                used += e.count
            }
            let n = String(notes.prefix(budget / 3))
            var prompt = "問題：\(question)\n\n"
            if !lines.isEmpty { prompt += "網路上查到的資料：\n" + lines.joined(separator: "\n") + "\n\n" }
            if !n.isEmpty { prompt += "NineSun 自己先整理的重點（可能不完整、也可能理解錯問題，僅供參考）：\n\(n)\n\n" }
            prompt += "請回答這個問題。"
            if let r = await respond(instructions: instructions(persona: persona), prompt: prompt) { return r }
            budget /= 2
        }
        return nil
    }

    /// 聊天：沒有要查的資料，直接用 NineSun 的個性回答；chart 是命理引擎算好的結果（不能改）
    static func chat(_ text: String, history: [(fromUser: Bool, text: String)], chart: String, persona: String) async -> String? {
        var prompt = ""
        let past = history.suffix(6).map { ($0.fromUser ? "對方：" : "NineSun：") + String($0.text.prefix(150)) }
        if !past.isEmpty { prompt += "剛才的對話：\n" + past.joined(separator: "\n") + "\n\n" }
        if !chart.isEmpty {
            prompt += "【NineSun 用九型十二宮算出來的結果】（這是精確推算，宮位、數字、好正壞、年份一個都不能改，也不要自己另外算）\n"
                + String(chart.prefix(900)) + "\n\n用上面的結果回答：先講結論，再用白話說為什麼，最後給一個具體可做的建議。\n\n"
        }
        prompt += "對方說：\(text)"
        return await respond(instructions: instructions(persona: persona), prompt: prompt, maxTokens: 600)
    }
}
