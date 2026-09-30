import EchoCore
import Foundation

/// 網頁 ↔ 引擎的橋：網頁把資料檔的位元組傳進來、把使用者的話傳進來，拿回 JSON 回覆。
var files: [Int32: Data] = [:]
var engine: EchoEngine?
var history: [ChatTurn] = []
var rules = RuleBook()
var output: [UInt8] = []

struct Input: Decodable { let text: String; let profile: UserProfile; let now: Double }
struct Output: Encodable {
    let text: String
    let source: String
    let card: FortuneCard?
    let profile: UserProfile?
    let webQuery: String?
    let webAugment: [String]
}

@_expose(wasm, "ns_alloc")
@_cdecl("ns_alloc")
public func ns_alloc(_ n: Int32) -> UnsafeMutableRawPointer {
    UnsafeMutableRawPointer.allocate(byteCount: Int(max(n, 1)), alignment: 16)
}

@_expose(wasm, "ns_free")
@_cdecl("ns_free")
public func ns_free(_ p: UnsafeMutableRawPointer) { p.deallocate() }

/// kind：0 權重、1 模型設定、2 i18n、3 對話庫、4 十二宮詞庫、10–13 資料庫 zh/en/es/it
@_expose(wasm, "ns_file")
@_cdecl("ns_file")
public func ns_file(_ kind: Int32, _ p: UnsafeRawPointer, _ n: Int32) {
    files[kind] = Data(bytes: p, count: Int(n))
}

@_expose(wasm, "ns_start")
@_cdecl("ns_start")
public func ns_start() -> Int32 {
    guard let w = files[0], let m = files[1], let model = try? EchoModel(weights: w, metaJSON: m) else { return 0 }
    let e = EchoEngine(model: model)
    if let d = files[2] { e.i18n = try? I18N(json: d) }
    if let d = files[3] { e.chatBank = try? ChatBank(json: d) }
    if let d = files[4] { e.core = try? PalaceCore(json: d) }
    for (i, L) in [Lang.zh, .en, .es, .it].enumerated() {
        if let d = files[Int32(10 + i)] { e.knowledge[L] = try? KnowledgeBase(json: d, lang: L) }
    }
    files[0] = nil
    engine = e
    return 1
}

@_expose(wasm, "ns_send")
@_cdecl("ns_send")
public func ns_send(_ p: UnsafeRawPointer, _ n: Int32) -> Int32 {
    let data = Data(bytes: p, count: Int(n))
    guard let engine, let input = try? JSONDecoder().decode(Input.self, from: data) else { return put(["error": "bad input"]) }
    let ctx = EchoEngine.Context(profile: input.profile, rules: rules, now: Date(timeIntervalSince1970: input.now / 1000))
    let reply = engine.reply(to: input.text, history: history, context: ctx)
    if let r = reply.rules { rules = r }
    history.append(ChatTurn(role: .user, text: input.text))
    history.append(reply.turn)
    if history.count > 40 { history.removeFirst(history.count - 40) }
    let out = Output(text: reply.turn.text, source: reply.turn.source.rawValue, card: reply.turn.card, profile: reply.profile,
                     webQuery: reply.webQuery, webAugment: reply.webAugment)
    return put(out)
}

@_expose(wasm, "ns_reset")
@_cdecl("ns_reset")
public func ns_reset() { history = []; rules = RuleBook() }

@_expose(wasm, "ns_out")
@_cdecl("ns_out")
public func ns_out() -> UnsafePointer<UInt8>? { output.withUnsafeBufferPointer { $0.baseAddress } }

func put<T: Encodable>(_ v: T) -> Int32 {
    output = Array((try? JSONEncoder().encode(v)) ?? Data("{}".utf8))
    return Int32(output.count)
}
