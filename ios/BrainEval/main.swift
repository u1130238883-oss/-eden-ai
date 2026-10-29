import Foundation

setvbuf(stdout, nil, _IOLBF, 0)   // 一行一行輸出，CI 的紀錄才看得到進度

// 大腦評測（GitHub 的 Mac 上跑）：真的把模型讀進來，用 NineSun 的提示問一批問題，印出回答和速度。
// 用法：brain-eval 模型.gguf 題目.txt [gpu]
// 題目檔每題用一行 ---- 分開；開頭可以寫：
//   lang: en            回答的語言
//   facts: …            NineSun 引擎查到的事實
//   evidence: …         網路資料（可以好幾行）
//   reading: …          命盤推算結果
//   history: user|…     前面的對話（user／ai）
//   q: …                問題
let args = CommandLine.arguments
guard args.count >= 3 else { print("用法：brain-eval 模型.gguf 題目.txt [gpu]"); exit(2) }
let gpu = args.count > 3 && args[3] == "gpu"

print("繁體轉換測試：", LocalBrain.tidy("我觉得这个软件的视频质量很好，网络也很快。", lang: "zh"))

let loadStart = Date()
let runner: LlamaRunner
do { runner = try LlamaRunner(path: args[1], contextSize: 4096, gpu: gpu, threads: ProcessInfo.processInfo.activeProcessorCount) } catch { print("讀不進模型：\(error)"); exit(1) }
print(String(format: "模型：%@ 讀取 %.1f 秒（gpu=%@）", (args[1] as NSString).lastPathComponent, Date().timeIntervalSince(loadStart), gpu ? "on" : "off"))
// 看這個模型的對話格式排得對不對
print("對話格式：", runner.chatPrompt([("system", "S"), ("user", "U")]).debugDescription)

let raw = try String(contentsOfFile: args[2], encoding: .utf8)
var totalTok = 0, totalSec = 0.0
for block in raw.components(separatedBy: "\n----\n") {
    var lang = "zh", facts = "", reading = "", q = ""
    var evidence: [String] = [], history: [LocalBrain.Turn] = []
    for line in block.split(separator: "\n").map(String.init) {
        if line.hasPrefix("lang: ") { lang = String(line.dropFirst(6)) }
        else if line.hasPrefix("facts: ") { facts += String(line.dropFirst(7)) + "\n" }
        else if line.hasPrefix("evidence: ") { evidence.append(String(line.dropFirst(10))) }
        else if line.hasPrefix("reading: ") { reading += String(line.dropFirst(9)) + "\n" }
        else if line.hasPrefix("history: ") {
            let p = line.dropFirst(9).split(separator: "|", maxSplits: 1).map(String.init)
            if p.count == 2 { history.append(LocalBrain.Turn(fromUser: p[0] == "user", text: p[1])) }
        }
        else if line.hasPrefix("q: ") { q = String(line.dropFirst(3)) }
    }
    guard !q.isEmpty else { continue }
    let mode: LocalBrain.Mode = !reading.isEmpty ? .reading : (!facts.isEmpty || !evidence.isEmpty) ? .grounded : .chat
    let user = LocalBrain.userMessage(question: q, facts: facts.trimmingCharacters(in: .whitespacesAndNewlines), evidence: evidence,
                                      reading: reading.trimmingCharacters(in: .whitespacesAndNewlines), lang: lang)
    let prompt = runner.chatPrompt(LocalBrain.messages(system: LocalBrain.system(lang: lang), history: history, user: user))
    do {
        let r = try runner.generate(prompt: prompt, maxTokens: mode == .chat ? 300 : 400, temperature: mode == .chat ? 0.7 : 0.4,
                                    stop: LocalBrain.stops, seed: 42)
        totalTok += r.tokens; totalSec += r.seconds
        print("\n=== \(q)  [\(mode)]")
        print(LocalBrain.tidy(r.text, lang: lang))
        if r.text.contains("<|") || r.text.contains("|>") { print("（原文有控制字：\(r.text.prefix(200).debugDescription)）") }
        print(String(format: "（提示 %d 字元、寫 %d 個 token、%.1f 秒、%.1f token/秒）", r.promptTokens, r.tokens, r.seconds, r.tokensPerSecond))
    } catch {
        print("\n=== \(q)\n失敗：\(error)")
    }
}
print(String(format: "\n總計：%d token，%.0f 秒，平均 %.1f token/秒", totalTok, totalSec, totalSec > 0 ? Double(totalTok) / totalSec : 0))
