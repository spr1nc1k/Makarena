import SwiftUI
import WebKit

struct StealthWebView: UIViewRepresentable {
    @Binding var urlString: String
    @Binding var isLoading: Bool
    @Binding var statusMessage: String
    let webView: WKWebView

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: StealthWebView

        init(_ parent: StealthWebView) {
            self.parent = parent
        }

        // WKNavigationDelegate
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                if let currentURL = webView.url?.absoluteString {
                    self.parent.urlString = currentURL
                }
            }
        }

        // WKScriptMessageHandler (odpowiedź z JS)
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "MakarenaHandler",
                  let body = message.body as? [String: Any],
                  let action = body["action"] as? String else { return }

            if action == "questionDataExtracted", let data = body["data"] as? [String: Any] {
                handleQuestionData(data: data)
            }
        }

        private func handleQuestionData(data: [String: Any]) {
            let type = data["type"] as? String ?? ""
            let question = data["question"] as? String ?? ""

            if type == "closed", let optionsDict = data["options"] as? [[String: Any]] {
                let options = optionsDict.compactMap { $0["text"] as? String }
                
                DispatchQueue.main.async {
                    self.parent.statusMessage = "Analizuję pytanie zamknięte..."
                }

                AIService.shared.solveClosedQuestion(question: question, options: options) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let correctIndex):
                            self.parent.statusMessage = "Wyznaczono odpowiedź (Opcja \(correctIndex + 1))"
                            let js = "document.dispatchEvent(new CustomEvent('__makarena_action', { detail: { action: 'applyClosed', correctIndex: \(correctIndex) } }));"
                            self.parent.webView.evaluateJavaScript(js, completionHandler: nil)
                        case .failure(let error):
                            self.parent.statusMessage = "Błąd AI: \(error.localizedDescription)"
                        }
                    }
                }
            } else if type == "open" {
                DispatchQueue.main.async {
                    self.parent.statusMessage = "Analizuję pytanie otwarte..."
                }

                AIService.shared.solveOpenQuestion(question: question) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let answerText):
                            self.parent.statusMessage = "Wyznaczono odpowiedź otwartą"
                            // Escapowanie podwójnych cudzysłowów dla JS
                            let escaped = answerText.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: " ")
                            let js = "document.dispatchEvent(new CustomEvent('__makarena_action', { detail: { action: 'applyOpen', answerText: \"\(escaped)\" } }));"
                            self.parent.webView.evaluateJavaScript(js, completionHandler: nil)
                        case .failure(let error):
                            self.parent.statusMessage = "Błąd AI: \(error.localizedDescription)"
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.parent.statusMessage = "Nie wykryto formularza pytania na stronie."
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Autentyczny User-Agent iOS 17.5 Safari
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/605.1.15"
        
        // Zapewnienie pełnej obsługi Ciasteczek, LocalStorage i Pamięci Przeglądarki
        let config = webView.configuration
        config.websiteDataStore = WKWebsiteDataStore.default()
        let webpagePrefs = WKWebpagePreferences()
        webpagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = webpagePrefs
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        webView.navigationDelegate = context.coordinator

        // Konfiguracja skryptów wstrzykiwanych
        let contentController = webView.configuration.userContentController
        contentController.add(context.coordinator, name: "MakarenaHandler")

        // 1. Iniekcja skryptu bypass na poziomie documentStart (sprawdzamy Documents/Scripts przed Bundle)
        let bypassJS = loadScriptContent(filename: "testportal_bypass")
        let bypassScript = WKUserScript(source: bypassJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        contentController.addUserScript(bypassScript)

        // 2. Iniekcja skryptu AI Injector na poziomie documentEnd
        let aiJS = loadScriptContent(filename: "ai_injector")
        let aiScript = WKUserScript(source: aiJS, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(aiScript)

        // Domyślny url
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    private func loadScriptContent(filename: String) -> String {
        let fileManager = FileManager.default
        if let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let customScriptPath = docsDir.appendingPathComponent("Scripts/\(filename).js")
            if fileManager.fileExists(atPath: customScriptPath.path),
               let content = try? String(contentsOf: customScriptPath, encoding: .utf8) {
                print("[StealthWebView] Wczytano pobrany skrypt z Documents/\(filename).js")
                return content
            }
        }
        
        if let bundlePath = Bundle.main.path(forResource: filename, ofType: "js"),
           let content = try? String(contentsOfFile: bundlePath, encoding: .utf8) {
            return content
        }
        
        return filename == "testportal_bypass" ? getInlineBypassJS() : getInlineAIJS()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // Wywołanie analizy pytania przez skrypt JS
    public static func triggerAIAnalysis(webView: WKWebView) {
        let js = "document.dispatchEvent(new CustomEvent('__makarena_action', { detail: { action: 'analyze' } }));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // Wywołanie Panic Mode w przeglądarce
    public static func triggerPanicMode(webView: WKWebView) {
        let js = "document.dispatchEvent(new CustomEvent('__makarena_action', { detail: { action: 'panic' } }));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func getInlineBypassJS() -> String {
        return """
        (function() {
            let nativePostMessage = null;
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.MakarenaHandler) {
                nativePostMessage = window.webkit.messageHandlers.MakarenaHandler.postMessage.bind(window.webkit.messageHandlers.MakarenaHandler);
                try { delete window.webkit; } catch(e) { Object.defineProperty(window, 'webkit', { get: function() { return undefined; }, configurable: true, enumerable: false }); }
            }
            window.__makarenaNativeSend = function(data) { if (nativePostMessage) nativePostMessage(data); };
            Object.defineProperty(window, '__makarenaNativeSend', { enumerable: false, writable: false, configurable: true });
            try {
                Object.defineProperty(Document.prototype, 'visibilityState', { get: function() { return 'visible'; }, configurable: true, enumerable: true });
                Object.defineProperty(Document.prototype, 'hidden', { get: function() { return false; }, configurable: true, enumerable: true });
                Object.defineProperty(Document.prototype, 'hasFocus', { value: function() { return true; }, writable: true, configurable: true, enumerable: true });
            } catch(e) {}
        })();
        """
    }

    private func getInlineAIJS() -> String {
        return """
        (function() {
            let isPanic = false;
            document.addEventListener('__makarena_action', function(e) {
                if (!e || !e.detail) return;
                let action = e.detail.action;
                if (action === 'analyze') {
                    isPanic = false;
                    let q = document.querySelector('.question_text_content, .question_content, h1, h2, h3') || document.body;
                    let opts = Array.from(document.querySelectorAll('.question_option_wrapper, .answer_container, label.answer')).map((el, i) => ({ id: i, text: el.innerText.trim() }));
                    let openInput = document.querySelector('textarea, input[type="text"]');
                    let data = { type: opts.length > 0 ? 'closed' : (openInput ? 'open' : 'unknown'), question: q.innerText.trim(), options: opts };
                    if (window.__makarenaNativeSend) window.__makarenaNativeSend({ action: 'questionDataExtracted', data: data });
                } else if (action === 'applyClosed' && !isPanic) {
                    let opts = document.querySelectorAll('.question_option_wrapper, .answer_container, label.answer');
                    if (opts[e.detail.correctIndex]) opts[e.detail.correctIndex].style.fontWeight = '700';
                } else if (action === 'applyOpen' && !isPanic) {
                    let input = document.querySelector('textarea, input[type="text"]');
                    if (input) input.setAttribute('placeholder', e.detail.answerText);
                } else if (action === 'panic') {
                    isPanic = true;
                    let opts = document.querySelectorAll('.question_option_wrapper, .answer_container, label.answer');
                    opts.forEach(el => el.style.fontWeight = '');
                }
            });
        })();
        """
    }
}
