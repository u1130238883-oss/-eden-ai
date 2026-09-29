import EchoCore
import Foundation

/// 維基百科摘要（中文用繁體；其他語言用各自的維基百科）
enum WikiLookup {
    struct Summary { let title: String; let extract: String; let url: String }

    static func fetch(_ query: String, lang L: Lang = .zh) async -> Summary? {
        let host = "\(L.rawValue).wikipedia.org"
        guard let q = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let search = URL(string: "https://\(host)/w/api.php?action=opensearch&limit=1&format=json&search=\(q)") else { return nil }
        do {
            let (d, _) = try await URLSession.shared.data(from: search)
            guard let arr = try JSONSerialization.jsonObject(with: d) as? [Any], arr.count > 1,
                  let titles = arr[1] as? [String], let title = titles.first,
                  let enc = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://\(host)/api/rest_v1/page/summary/\(enc)") else { return nil }
            var req = URLRequest(url: url)
            req.setValue(L == .zh ? "zh-tw" : L.rawValue, forHTTPHeaderField: "Accept-Language")
            let (sd, _) = try await URLSession.shared.data(for: req)
            guard let obj = try JSONSerialization.jsonObject(with: sd) as? [String: Any],
                  let extract = obj["extract"] as? String else { return nil }
            let page = ((obj["content_urls"] as? [String: Any])?["mobile"] as? [String: Any])?["page"] as? String
            return Summary(title: obj["title"] as? String ?? title, extract: extract,
                           url: page ?? "https://\(host)/wiki/\(enc)")
        } catch {
            return nil
        }
    }
}
