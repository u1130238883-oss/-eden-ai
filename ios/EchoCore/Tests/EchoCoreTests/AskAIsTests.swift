import XCTest
@testable import EchoCore

/// 請其他 AI 幫忙：讀回答、分出一致和不同、拿網路資料查證（不用連網、不用金鑰）
final class AskAIsTests: XCTestCase {
    func testReadsConclusionAndPoints() {
        let t = "**結論：** 台北101高508公尺。\n- 地上101層\n- 2004年落成\n1. 曾是世界最高\n其他說明"
        XCTAssertEqual(AskAIs.conclusion(t), "台北101高508公尺。")
        XCTAssertEqual(AskAIs.points(t), ["地上101層", "2004年落成", "曾是世界最高"])
        // 沒照格式：取第一句
        XCTAssertEqual(AskAIs.conclusion("它大約384,400公里。月球是地球的衛星。"), "它大約384,400公里。")
        // 推理型模型的思考過程要拿掉
        XCTAssertEqual(AskAIs.stripThinking("<think>想一想……</think>\n結論：唐朝"), "結論：唐朝")
    }

    func testAgreement() {
        XCTAssertTrue(AskAIs.agree("508公尺", "台北101高508公尺"))
        XCTAssertTrue(AskAIs.agree("約 384,400 公里", "平均距離384400公里"))
        XCTAssertFalse(AskAIs.agree("508公尺", "500公尺"))
        XCTAssertFalse(AskAIs.agree("會影響睡眠", "不會影響睡眠"))
    }

    func testParsesProviderResponses() {
        let or = #"{"choices":[{"message":{"role":"assistant","content":"結論：唐朝\n- 李白是盛唐詩人"}}]}"#.data(using: .utf8)
        XCTAssertEqual(AskAIs.openRouterText(or), "結論：唐朝\n- 李白是盛唐詩人")
        let g = #"{"candidates":[{"content":{"parts":[{"text":"結論：508公尺"}]},"finishReason":"STOP"}]}"#.data(using: .utf8)
        XCTAssertEqual(AskAIs.geminiText(g).text, "結論：508公尺")
        let blocked = #"{"promptFeedback":{"blockReason":"SAFETY"}}"#.data(using: .utf8)
        XCTAssertNil(AskAIs.geminiText(blocked).text)
        XCTAssertTrue(AskAIs.geminiText(blocked).blocked)
        let models = #"{"data":[{"id":"deepseek/deepseek-chat-v3-0324:free","context_length":64000},{"id":"deepseek/deepseek-r1:free","context_length":64000},{"id":"qwen/qwen2.5-vl-72b-instruct:free","context_length":32000},{"id":"qwen/qwen3-235b-a22b:free","context_length":40000},{"id":"meta-llama/llama-3.3-70b-instruct:free","context_length":65000},{"id":"openai/gpt-4o","context_length":128000}]}"#.data(using: .utf8)
        let ids = AskAIs.freeModelIDs(models) ?? []
        XCTAssertEqual(AskAIs.pickFamilies(ids), ["deepseek/deepseek-chat-v3-0324:free", "qwen/qwen3-235b-a22b:free", "meta-llama/llama-3.3-70b-instruct:free"])
        XCTAssertEqual(AskAIs.displayNames(["deepseek/deepseek-chat-v3-0324:free", "anthropic/claude-sonnet", "x-ai/grok-4"]), ["DeepSeek", "Claude", "Grok"])
    }

    func testSummaryShowsAgreementDifferenceAndVerdict() {
        var web = WebAgent.Result(text: "", card: nil, found: true, engines: [:])
        web.confident = false
        web.evidence = ["台北101樓高508公尺，地上101層。（zh.wikipedia.org）"]
        let replies = [
            AskAIs.Reply(name: "DeepSeek", text: "結論：台北101高508公尺。\n- 地上101層", error: nil),
            AskAIs.Reply(name: "Qwen", text: "結論：508公尺", error: nil),
            AskAIs.Reply(name: "Llama", text: "結論：大約500公尺", error: nil),
            AskAIs.Reply(name: "Gemini", text: "", error: "被 Gemini 的安全過濾擋下"),
        ]
        let s = AskAIs.summarize(question: "台北101有多高？", replies: replies, web: web)
        XCTAssertTrue(s.contains("沒把握"), s)
        XCTAssertTrue(s.contains("✅ 一致：DeepSeek、Qwen"), s)
        XCTAssertTrue(s.contains("⚠️ 不同：Llama"), s)
        XCTAssertTrue(s.contains("有網路資料支持"), s)
        XCTAssertTrue(s.contains("【Gemini】沒有回答"), s)

        // 自己查到有出處的答案、跟所有 AI 都不一樣：以有出處的為準
        var sure = WebAgent.Result(text: "", card: nil, found: true, engines: [:])
        sure.confident = true
        sure.shortAnswer = "508公尺"
        let s2 = AskAIs.summarize(question: "台北101有多高？", replies: [AskAIs.Reply(name: "Llama", text: "結論：大約500公尺", error: nil)], web: sure)
        XCTAssertTrue(s2.contains("以有出處的資料為準"), s2)
    }

    /// 連不上時要講出真正的原因和該怎麼辦（之前只顯示「找不到這個模型」）
    func testExplainsRealErrors() {
        let policy = #"{"error":{"message":"No endpoints found matching your data policy (Free model publication). Configure: https://openrouter.ai/settings/privacy","code":404}}"#.data(using: .utf8)
        let e = AskAIs.explain(code: 404, data: policy, failure: nil)
        XCTAssertTrue(e.contains("data policy") && e.contains("openrouter.ai/settings/privacy"), e)
        let key = #"{"error":{"message":"User not found.","code":401}}"#.data(using: .utf8)
        XCTAssertTrue(AskAIs.explain(code: 401, data: key, failure: nil).contains("重新建立"))
        XCTAssertTrue(AskAIs.explain(code: 0, data: nil, failure: "The request timed out.").contains("timed out"))
        XCTAssertEqual(AskAIs.serverMessage(#"{"message":"bad"}"#.data(using: .utf8)), "bad")
    }

    func testWhenToAsk() {
        var r = WebAgent.Result(text: "", card: nil, found: true, engines: [:])
        r.confident = true
        r.want = "number"
        XCTAssertFalse(AskAIs.shouldAsk(r))
        r.want = "reason"
        XCTAssertTrue(AskAIs.shouldAsk(r))
        r.want = "number"
        r.confident = false
        XCTAssertTrue(AskAIs.shouldAsk(r))
        XCTAssertFalse(AskAIs.Config().enabled)
        XCTAssertTrue(AskAIs.Config(openRouterKey: " sk-or-x ").enabled)
    }
}
