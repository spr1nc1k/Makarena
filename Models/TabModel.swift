import Foundation
import WebKit
import SwiftUI

public class WebTab: Identifiable, ObservableObject {
    public let id: UUID = UUID()
    @Published public var title: String = "Nowa karta"
    @Published public var urlString: String = "about:blank"
    @Published public var isLoading: Bool = false
    @Published public var statusMessage: String = "Gotowy"
    public let webView: WKWebView

    public init(urlString: String = "about:blank") {
        self.urlString = urlString
        
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        self.webView = WKWebView(frame: .zero, configuration: config)
    }
}
