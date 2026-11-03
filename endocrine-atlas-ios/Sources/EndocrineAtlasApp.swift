import SwiftUI
import WebKit

@main
struct EndocrineAtlasApp: App {
    var body: some Scene {
        WindowGroup {
            AtlasWebView()
                .ignoresSafeArea()
                .background(Color(UIColor.systemBackground))
        }
    }
}

/// Shows the bundled, fully offline atlas page (Web/index.html + Web/data.js).
struct AtlasWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()   // keeps quiz records and settings
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.allowsBackForwardNavigationGestures = false
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            web.loadHTMLString("<h2 style='font-family:-apple-system;padding:40px'>找不到頁面檔案。</h2>", baseURL: nil)
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
