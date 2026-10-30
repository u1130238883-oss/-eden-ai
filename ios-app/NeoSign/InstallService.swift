import Foundation

/// iOS 只允許從 HTTPS 網站安裝 App，所以簽好的 IPA 上傳到你自己的簽名網站（mysign），
/// 由網站生成 itms-services 安裝鏈接。
enum InstallService {
    static let defaultServer = "https://mysign.onrender.com"

    static func baseURL(_ server: String) throws -> URL {
        let trimmed = server.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: trimmed), url.scheme == "https", url.host != nil else {
            throw AppError("伺服器地址要以 https:// 開頭")
        }
        return url
    }

    static func login(server: String, password: String) async throws {
        let base = try baseURL(server)
        var request = URLRequest(url: base.appendingPathComponent("api/login"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120 // 免費伺服器休眠後喚醒要一點時間
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let encoded = password.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
        request.httpBody = Data("password=\(encoded)".utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        try check(response, data)
    }

    /// 上傳簽好的 IPA，返回 itms-services 安裝鏈接。
    static func upload(ipa: URL, server: String, password: String) async throws -> URL {
        try await login(server: server, password: password)

        let base = try baseURL(server)
        let boundary = "NeoSign-\(UUID().uuidString)"
        var request = URLRequest(url: base.appendingPathComponent("api/upload"))
        request.httpMethod = "POST"
        request.timeoutInterval = 900
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let body = try multipartBody(file: ipa, field: "ipa", boundary: boundary)
        defer { try? FileManager.default.removeItem(at: body) }

        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: body)
        try check(response, data)

        struct Result: Decodable { let install_url: String }
        let result = try JSONDecoder().decode(Result.self, from: data)
        guard let url = URL(string: result.install_url) else {
            throw AppError("伺服器返回的安裝鏈接無效")
        }
        return url
    }

    private static func multipartBody(file: URL, field: String, boundary: String) throws -> URL {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("upload-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let writer = try FileHandle(forWritingTo: output)
        defer { try? writer.close() }

        let header = "--\(boundary)\r\n"
            + "Content-Disposition: form-data; name=\"\(field)\"; filename=\"app.ipa\"\r\n"
            + "Content-Type: application/octet-stream\r\n\r\n"
        try writer.write(contentsOf: Data(header.utf8))

        let reader = try FileHandle(forReadingFrom: file)
        defer { try? reader.close() }
        while let chunk = try reader.read(upToCount: 4 << 20), !chunk.isEmpty {
            try writer.write(contentsOf: chunk)
        }
        try writer.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))
        return output
    }

    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AppError("伺服器沒有響應") }
        guard http.statusCode == 200 else {
            struct Detail: Decodable { let detail: String }
            if let detail = try? JSONDecoder().decode(Detail.self, from: data) {
                throw AppError(http.statusCode == 401 ? "網站密碼錯誤" : detail.detail)
            }
            if http.statusCode == 404 {
                throw AppError("網站版本太舊，請在 Render 重新部署最新代碼")
            }
            throw AppError("伺服器錯誤 \(http.statusCode)")
        }
    }
}
