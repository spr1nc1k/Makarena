import SwiftUI
import WebKit

struct ContentView: View {
    @State private var urlInput: String = "https://www.testportal.pl"
    @State private var currentURL: String = "https://www.testportal.pl"
    @State private var isLoading: Bool = false
    @State private var statusMessage: String = "Ochrona Testportal Aktywna"
    @State private var showSettings: Bool = false

    @StateObject private var volumeObserver = VolumeKeyObserver.shared
    private let webView = WKWebView()

    @AppStorage("gemini_api_key") private var apiKey: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Pasek adresu (Stealth Navigation Bar)
            HStack(spacing: 8) {
                Button(action: {
                    if webView.canGoBack { webView.goBack() }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.primary)
                }

                Button(action: {
                    if webView.canGoForward { webView.goForward() }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.primary)
                }

                TextField("Wpisz adres URL...", text: $urlInput, onCommit: {
                    loadURL(urlInput)
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.URL)
                .autocapitalization(.none)

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        webView.reload()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.primary)
                    }
                }

                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))

            // Główny widok Przeglądarki
            ZStack(alignment: .top) {
                StealthWebView(
                    urlString: $currentURL,
                    isLoading: $isLoading,
                    statusMessage: $statusMessage,
                    webView: webView
                )

                // Subtelny dyskretny wskaźnik stanu na samej górze
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text(statusMessage)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.8))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.03))
                .allowsHitTesting(false)
            }

            // Dyskretne gesty ratunkowe na dole ekranu (w razie braku klawiszy głośności)
            HStack(spacing: 0) {
                // Lewy niewidzialny przycisk gestu (Panic Mode)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        triggerPanicMode()
                    }

                // Prawy niewidzialny przycisk gestu (AI Solve)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        triggerAIAnalysis()
                    }
            }
            .frame(height: 20)
            .background(Color.clear)
        }
        .onAppear {
            AIService.shared.apiKey = apiKey
            volumeObserver.startObserving()
        }
        .onReceive(volumeObserver.$lastTriggeredAction) { action in
            guard let action = action else { return }
            switch action {
            case .triggerAI:
                triggerAIAnalysis()
            case .triggerPanic:
                triggerPanicMode()
            }
            volumeObserver.lastTriggeredAction = nil
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func loadURL(_ targetURL: String) {
        var formatted = targetURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.hasPrefix("http://") && !formatted.hasPrefix("https://") {
            formatted = "https://" + formatted
        }
        urlInput = formatted
        if let url = URL(string: formatted) {
            webView.load(URLRequest(url: url))
        }
    }

    private func triggerAIAnalysis() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        statusMessage = "Wywoływanie AI..."
        StealthWebView.triggerAIAnalysis(webView: webView)
    }

    private func triggerPanicMode() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        statusMessage = "TRYB NAUCZYCIEL PATRZY"
        StealthWebView.triggerPanicMode(webView: webView)
    }
}
