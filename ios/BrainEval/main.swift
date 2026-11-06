import Foundation

setvbuf(stdout, nil, _IOLBF, 0)   // 一行一行輸出，CI 的紀錄才看得到進度

// 大腦考試（GitHub 的 Mac 上跑）：真的把模型讀進來，用 App 一模一樣的提示和設定回答考卷，回答存成 jsonl，
// 再用 BrainEval/exam/score.py 改分。
// 用法：brain-eval 模型.gguf 考卷.jsonl 回答.jsonl [gpu] [shard=K/N] [limit=M]
//   考卷每行一題（exam/ExamRouteTests 分流過的）：route = chat／grounded／translate／reading／roleplay／engine（引擎答，跳過）
//   回答檔已經有的題目會跳過（中斷了可以接著跑）
let args = CommandLine.arguments
guard args.count >= 4 else { print("用法：brain-eval 模型.gguf 考卷.jsonl 回答.jsonl [gpu] [shard=K/N] [limit=M]"); exit(2) }
let gpu = args.contains("gpu")
var shard = 0, shards = 1, limit = Int.max
for a in args.dropFirst(4) {
    if a.hasPrefix("shard="), let p = Optional(a.dropFirst(6).split(separator: "/")), p.count == 2 { shard = Int(p[0]) ?? 0; shards = Int(p[1]) ?? 1 }
    if a.hasPrefix("limit=") { limit = Int(a.dropFirst(6)) ?? limit }
}

// 模型寫 dry：不讀模型，只把每題的提示組出來（在沒有模型的機器上測整個流程）
let dry = args[1] == "dry"
let loadStart = Date()
var runner: LlamaRunner?
if !dry {
    do { runner = try LlamaRunner(path: args[1], contextSize: 2048, gpu: gpu, threads: ProcessInfo.processInfo.activeProcessorCount) } catch { print("讀不進模型：\(error)"); exit(1) }
    print(String(format: "模型：%@ 讀取 %.1f 秒（gpu=%@）", (args[1] as NSString).lastPathComponent, Date().timeIntervalSince(loadStart), gpu ? "on" : "off"))
}

// 已經答過的
let outURL = URL(fileURLWithPath: args[3])
var done = Set<String>()
if let old = try? String(contentsOf: outURL, encoding: .utf8) {
    for l in old.split(separator: "\n") {
        if let o = try? JSONSerialization.jsonObject(with: Data(l.utf8)) as? [String: Any], let id = o["id"] as? String { done.insert(id) }
    }
}
if !FileManager.default.fileExists(atPath: outURL.path) { FileManager.default.createFile(atPath: outURL.path, contents: nil) }
let out = try FileHandle(forWritingTo: outURL)
out.seekToEndOfFile()

func seed(_ id: String) -> UInt32 { id.unicodeScalars.reduce(UInt32(2166136261)) { ($0 ^ $1.value) &* 16777619 } | 1 }

let lines = try String(contentsOfFile: args[2], encoding: .utf8).split(separator: "\n")
var n = 0, totalTok = 0, totalSec = 0.0
for (i, line) in lines.enumerated() where i % shards == shard {
    guard n < limit,
          let it = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
          let id = it["id"] as? String, let q = it["q"] as? String,
          let route = it["route"] as? String, route != "engine", !done.contains(id) else { continue }
    n += 1
    let lang = it["lang"] as? String ?? "zh"
    let history = (it["history"] as? [[String]] ?? []).map { LocalBrain.Turn(fromUser: $0[0] == "user", text: $0[1]) }
    let mode: LocalBrain.Mode
    var system = LocalBrain.system(lang: lang)
    var user: String
    switch route {
    case "roleplay":
        mode = .roleplay
        let ch = it["character"] as? String ?? ""
        system = LocalBrain.roleplaySystem(character: ch, lang: lang)
        user = LocalBrain.roleplayUser(q, character: ch, lang: lang)
    case "translate":
        mode = .grounded
        user = LocalBrain.userMessage(question: LocalBrain.translateQuestion(q, lang: lang), lang: lang)
    case "reading":
        mode = .reading
        user = LocalBrain.userMessage(question: q, reading: it["reading"] as? String ?? "", lang: lang)
    case "grounded":
        mode = .grounded
        let math = it["notes"] != nil && LocalBrain.isArithmetic(q)
        user = LocalBrain.userMessage(question: math ? LocalBrain.mathQuestion(q, lang: lang) : q, facts: it["facts"] as? String ?? "", evidence: it["evidence"] as? [String] ?? [],
                                      hint: it["hint"] as? String ?? "", notes: it["notes"] as? String ?? "", lang: lang)
    default:
        // App 的 brainChat：算數的應用題用比較穩的設定、一步一步算
        let math = LocalBrain.isArithmetic(q)
        mode = math ? .grounded : .chat
        user = LocalBrain.userMessage(question: math ? LocalBrain.mathQuestion(q, lang: lang) : q, hint: it["hint"] as? String ?? "", lang: lang)
    }
    let (temp, most) = LocalBrain.settings(mode)
    var rec: [String: Any] = ["id": id]
    guard let runner else {
        let msgs = LocalBrain.messages(system: system, history: history, user: user)
        rec["answer"] = LocalBrain.tidy("（dry）" + user, lang: lang)
        rec["prompt_chars"] = msgs.reduce(0) { $0 + $1.content.count }
        let d = try JSONSerialization.data(withJSONObject: rec, options: [.sortedKeys])
        out.write(d + Data("\n".utf8))
        continue
    }
    let prompt = runner.chatPrompt(LocalBrain.messages(system: system, history: history, user: user))
    do {
        let r = try runner.generate(prompt: prompt, maxTokens: most, temperature: temp, stop: LocalBrain.stops, seed: seed(id))
        let text = LocalBrain.followFormat(question: q, answer: LocalBrain.tidy(r.text, lang: lang))
        rec["answer"] = text
        rec["tokens"] = r.tokens
        rec["seconds"] = r.seconds
        rec["prompt_tokens"] = r.promptTokens
        totalTok += r.tokens; totalSec += r.seconds
        print("\n=== [\(id) \(route)] \(q)\n\(text)")
        print(String(format: "（提示 %d、寫 %d token、%.1f 秒、%.1f token/秒）", r.promptTokens, r.tokens, r.seconds, r.tokensPerSecond))
    } catch {
        rec["answer"] = ""
        rec["error"] = "\(error)"
        print("\n=== [\(id)] \(q)\n失敗：\(error)")
    }
    let d = try JSONSerialization.data(withJSONObject: rec, options: [.sortedKeys])
    out.write(d + Data("\n".utf8))
}
try out.close()
print(String(format: "\n總計：%d 題，%d token，%.0f 秒，平均 %.1f token/秒", n, totalTok, totalSec, totalSec > 0 ? Double(totalTok) / totalSec : 0))
