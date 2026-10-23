import Foundation

/// 錄音帶：把真的上網拿到的搜尋結果和網頁文字錄下來，之後可以離線重播。
/// 用途：訓練「從網頁裡抓到答案」——同一批真實的網頁，改了挑句子、判斷答案的方法後，馬上重跑看有沒有變好。
/// （CI 的機器有網路，負責錄；開發的機器沒有網路，負責重播、改進）
public final class WebTape: @unchecked Sendable {
    public static var shared: WebTape?

    public let replaying: Bool
    private let lock = NSLock()
    private var searches: [String: WebSearch.Answer] = [:]
    private var pages: [String: String] = [:]
    /// 重播時找不到的查詢（查詢的方法改了，錄音帶裡沒有）
    public private(set) var misses: [String] = []

    struct Store: Codable {
        var searches: [String: WebSearch.Answer]
        var pages: [String: String]
    }

    public init(replaying: Bool) { self.replaying = replaying }

    public convenience init(contentsOf url: URL) throws {
        self.init(replaying: true)
        let s = try JSONDecoder().decode(Store.self, from: Data(contentsOf: url))
        searches = s.searches; pages = s.pages
    }

    static func key(_ q: String, _ L: Lang, news: Bool, light: Bool) -> String {
        "\(L.rawValue)|\(news ? "n" : "")\(light ? "l" : "")|\(q)"
    }

    func search(_ q: String, _ L: Lang, news: Bool, light: Bool) -> WebSearch.Answer? {
        lock.lock(); defer { lock.unlock() }
        let k = WebTape.key(q, L, news: news, light: light)
        // 輕量／完整查詢互相補位：方法改了也盡量用得上
        if let a = searches[k] ?? searches[WebTape.key(q, L, news: news, light: !light)] ?? searches[WebTape.key(q, L, news: !news, light: light)] { return a }
        misses.append(q)
        return nil
    }

    func page(_ url: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        if let p = pages[url] { return p }
        misses.append(url)
        return nil
    }

    func record(_ q: String, _ L: Lang, news: Bool, light: Bool, _ a: WebSearch.Answer) {
        lock.lock(); defer { lock.unlock() }
        searches[WebTape.key(q, L, news: news, light: light)] = a
    }

    func record(page url: String, _ text: String?) {
        guard let text else { return }
        lock.lock(); defer { lock.unlock() }
        // 網頁太長的只留前面（答案幾乎都在前面），錄音帶才不會太大
        pages[url] = String(text.prefix(40_000))
    }

    public var counts: (searches: Int, pages: Int) {
        lock.lock(); defer { lock.unlock() }
        return (searches.count, pages.count)
    }

    public func save(to url: URL) throws {
        lock.lock(); defer { lock.unlock() }
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        try e.encode(Store(searches: searches, pages: pages)).write(to: url)
    }
}
