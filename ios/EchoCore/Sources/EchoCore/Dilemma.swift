import Foundation

/// 假設題、兩難題（「如果有兩個按鈕…你怎麼選」「媽媽和女友同時掉到水裡你救誰」「只能選一個你選哪個」）。
/// 這種題目問的是 NineSun 自己的想法和價值觀，不是命盤、不是心情、也不是要上網查的事實——
/// 引擎以前看到「別人」「死掉」就當成在說人際或心情（使用者的截圖：按鈕題被答成 7 宮婚姻運）。
/// 只用 Foundation：大腦考試（BrainEval）會把這個檔案和 LocalBrain.swift 一起編
public enum Dilemma {
    public enum Kind { case selfOrOthers, fewOrMany, whoToSave, other }

    static func has(_ t: String, _ pattern: String) -> Bool { t.range(of: pattern, options: .regularExpression) != nil }

    /// 這句話是在出假設題、要對方選
    public static func looks(_ raw: String) -> Bool {
        let t = raw.lowercased().replacingOccurrences(of: " ", with: "")
        guard t.count >= 8 else { return false }
        // 問自己的命、運勢的不算（「如果我今年換工作你怎麼看」）
        if has(t, "運勢|流年|大運|命盤|八字|紫微|塔羅|占卜|卦") { return false }
        let setup = has(t, "如果|假如|假設|假使|要是|萬一|有一個按鈕|有兩個按鈕|只能選|只能救|只能留|二選一|兩個選|同時掉|what if|if you had to|would you rather|trolley")
        let ask = has(t, "[你妳您](會|要|該|想)?(怎麼|如何)(選|做|辦|決定)|[你妳您](會|要|想)?選(哪|什麼|擇|誰|a|b)|[你妳您]會(按|救|選|留)|[你妳您](先|會先|要先)?救(誰|哪)|[你妳您]怎麼選|[你妳您]會不會(按|救|選)|which (one )?would you|what would you (do|choose|pick)|would you rather|who would you save")
        return setup && ask
    }

    public static func kind(_ raw: String) -> Kind {
        let t = raw.replacingOccurrences(of: " ", with: "")
        let life = has(t, "死|活|救|命|犧牲|消失")
        let me = has(t, "[你妳我]自己|[你妳]會死|[你妳]就會死|[你妳]死|犧牲[你妳自]|[你妳]消失")
        let others = has(t, "別人|其他人|所有人|大家|全人類|全世界|陌生人|其他的人")
        if life && me && others { return .selfOrOthers }
        if life && has(t, "一個人|一人|少數|[1１]個人") && has(t, "[五5５十]個人|很多人|多數|一群|更多人|[二兩三四五六七八九十百千]+個人") { return .fewOrMany }
        if has(t, "救誰|先救|救哪") { return .whoToSave }
        return .other
    }

    /// 沒有大腦時引擎自己的回答：照 NineSun 的價值觀選一邊、說理由，也承認另一邊的道理，再把問題丟回去。
    /// （價值觀是使用者定的：有主見、敢下結論、講義氣；不是背答案——同一類的題目都照同一個原則回答）
    public static func stance(_ raw: String, zh: Bool = true) -> String {
        guard zh else {
            switch kind(raw) {
            case .selfOrOthers: return "I'd press the one that lets everyone else live. One life against many isn't a hard sum, even when the one is mine. To be honest though, saying it is cheap; nobody knows what their hand does until the button is real. What would you pick?"
            case .fewOrMany: return "I'd save the larger group, and I wouldn't pretend that makes it clean: choosing still means someone dies because of what I did. Fewer deaths is the least bad outcome, not a good one. Which way do you lean?"
            case .whoToSave: return "I'd save whoever I can actually reach first. In a real emergency you don't get to rank people; hesitating is how you lose both. The question is really asking who matters more to you, and that one only you can answer."
            case .other: return "There's no textbook answer to a hypothetical like this, so here's my rule: pick the option that hurts the fewest people and that I could still live with afterwards. Tell me which way you lean and why, and I'll argue it with you."
            }
        }
        switch kind(raw) {
        case .selfOrOthers:
            return "我會按讓別人活下來的那個。\n\n理由不複雜：一邊是一條命，另一邊是很多條命，就算那一條是我自己的，這筆帳也沒什麼好算的。而且靠全世界死光換來的「活著」，剩我一個也不知道要幹嘛。\n\n但我不想把話說得太漂亮：嘴上選很容易，按鈕真的在眼前時，手會不會抖沒有人敢保證，會想活下去也不丟臉。這題真正在問的是「自己」和「別人」在你心裡各有多重——你會怎麼選？"
        case .fewOrMany:
            return "我會救人多的那一邊。\n\n理由：都是人命，少死幾個就是比較不糟的結果。但我不會假裝這樣選很乾淨——動手的那一刻，那個人等於是因為我的決定而死的，這跟「袖手旁觀」不一樣，選了就要自己扛。\n\n反過來說，堅持不動手的人也有道理：他們在意的是「我不能親手害死一個無辜的人」。兩邊爭的其實是「結果比較重要」還是「底線比較重要」。你偏哪一邊？"
        case .whoToSave:
            return "我會先救離我最近、最救得到的那個。\n\n真的出事的時候沒有時間排名次，猶豫的那幾秒才是兩個都救不到的原因。這題表面在問救誰，其實是在逼人說出「誰比較重要」——而這個不需要用災難來證明，平常怎麼對人就已經回答了。\n\n如果你是被問的那個：不要選邊，直接說「我兩個都會拚命救」。如果你是想問的那個：你想聽到的答案是什麼？"
        case .other:
            return "這種假設題沒有標準答案，所以我講我的原則：先看哪個選擇傷到的人最少，再看做了以後我自己過不過得去。兩個都過得去，就選比較難回頭的那個先不要做。\n\n你把兩個選項各自會發生什麼事再講清楚一點，我就直接選一邊給你看，不會跟你說「都可以」。你自己目前偏哪一邊？"
        }
    }
}
