import SwiftUI
import WebKit

struct ContentView: View {
    @State private var tabs: [WebTab] = [WebTab(urlString: "https://www.testportal.pl")]
    @State private var activeTabId: UUID = UUID()
    
    @State private var urlInput: String = "https://www.testportal.pl"
    @State private var showSettings: Bool = false
    @State private var showTabManager: Bool = false
    @State private var showFeatureMenu: Bool = false
    
    @StateObject private var volumeObserver = VolumeKeyObserver.shared
    public enum NotificationState {
        case activatedAI
        case deactivatedPanic
    }
    
    @State private var activeNotification: NotificationState? = nil
    
    private var activeTab: WebTab? {
        tabs.first(where: { $0.id == activeTabId }) ?? tabs.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pasek Nagłówka WhiteSolution WebSite
            HStack(spacing: 10) {
                // Logo & Tytuł WhiteSolution
                HStack(spacing: 6) {
                    Image(systemName: "shield.bordercheck.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.blue)
                    Text("WhiteSolution")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()

                // Przycisk Menu Funkcji / Shield
                Button(action: {
                    showFeatureMenu = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 13))
                        Text("Funkcje")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }

                // Wskaźnik Liczby Kart
                Button(action: {
                    showTabManager = true
                }) {
                    Text("\(tabs.count)")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 22, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary, lineWidth: 1.5)
                        )
                }

                // Ustawienia
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))

            // Pasek Nawigacji i Adresu URL
            HStack(spacing: 8) {
                Button(action: {
                    activeTab?.webView.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(activeTab?.webView.canGoBack == true ? .primary : .gray.opacity(0.4))
                }
                .disabled(activeTab?.webView.canGoBack == false)

                Button(action: {
                    activeTab?.webView.goForward()
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(activeTab?.webView.canGoForward == true ? .primary : .gray.opacity(0.4))
                }
                .disabled(activeTab?.webView.canGoForward == false)

                // Pole Adresu URL
                HStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    TextField("Wpisz adres lub szukaj...", text: $urlInput, onCommit: {
                        loadURL(urlInput)
                    })
                    .font(.system(size: 13))
                    .keyboardType(.URL)
                    .autocapitalization(.none)

                    if activeTab?.isLoading == true {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Button(action: {
                            activeTab?.webView.reload()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .background(Color(UIColor.systemBackground))

            Divider()

            // Główny Widok Przeglądarki
            ZStack(alignment: .topTrailing) {
                if let tab = activeTab {
                    StealthWebView(
                        urlString: Binding(
                            get: { tab.urlString },
                            set: { tab.urlString = $0; urlInput = $0 }
                        ),
                        isLoading: Binding(
                            get: { tab.isLoading },
                            set: { tab.isLoading = $0 }
                        ),
                        statusMessage: Binding(
                            get: { tab.statusMessage },
                            set: { tab.statusMessage = $0 }
                        ),
                        webView: tab.webView
                    )
                    .id(tab.id)
                }

                // Dyskretne Powiadomienie w Prawym Górnym Rogu (Kropka Zielona/Czerwona na 1.2 sekundy)
                if let notification = activeNotification {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(notification == .activatedAI ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                            .shadow(color: (notification == .activatedAI ? Color.green : Color.red).opacity(0.8), radius: 4)
                        Text(notification == .activatedAI ? "AI Aktywowane" : "Tryb Nauczyciel")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(12)
                    .padding(.top, 10)
                    .padding(.trailing, 10)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
                }
            }

            // Strefa gestów awaryjnych na dole ekranu
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        triggerPanicMode()
                    }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        triggerAIAnalysis()
                    }
            }
            .frame(height: 18)
            .background(Color.clear)
        }
        .onAppear {
            if let first = tabs.first {
                activeTabId = first.id
            }
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
        .sheet(isPresented: $showTabManager) {
            TabManagerView(tabs: $tabs, activeTabId: $activeTabId)
        }
        .sheet(isPresented: $showFeatureMenu) {
            FeatureMenuView(triggerAI: triggerAIAnalysis, triggerPanic: triggerPanicMode)
        }
    }

    private func loadURL(_ targetURL: String) {
        var formatted = targetURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.hasPrefix("http://") && !formatted.hasPrefix("https://") {
            if formatted.contains(".") && !formatted.contains(" ") {
                formatted = "https://" + formatted
            } else {
                formatted = "https://www.google.com/search?q=\(formatted.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? formatted)"
            }
        }
        urlInput = formatted
        if let tab = activeTab, let url = URL(string: formatted) {
            tab.urlString = formatted
            tab.webView.load(URLRequest(url: url))
        }
    }

    private func triggerAIAnalysis() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showNotification(.activatedAI)
        if let tab = activeTab {
            tab.statusMessage = "Wywoływanie AI..."
            StealthWebView.triggerAIAnalysis(webView: tab.webView)
        }
    }

    private func triggerPanicMode() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        showNotification(.deactivatedPanic)
        if let tab = activeTab {
            tab.statusMessage = "TRYB NAUCZYCIEL PATRZY"
            StealthWebView.triggerPanicMode(webView: tab.webView)
        }
    }

    private func showNotification(_ state: NotificationState) {
        withAnimation(.spring()) {
            activeNotification = state
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut) {
                if activeNotification == state {
                    activeNotification = nil
                }
            }
        }
    }
}

// Widok Menu Funkcji WhiteSolution
struct FeatureMenuView: View {
    @Environment(\.dismiss) var dismiss
    var triggerAI: () -> Void
    var triggerPanic: () -> Void

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Centrum Funkcji WhiteSolution")) {
                    Button(action: {
                        dismiss()
                        triggerAI()
                    }) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Wyznacz Odpowiedź (AI Solve)")
                                    .bold()
                                Text("Głośność w dół x2 / Dwu-klik prawy róg")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }

                    Button(action: {
                        dismiss()
                        triggerPanicMode()
                    }) {
                        HStack {
                            Image(systemName: "eye.slash.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading) {
                                Text("Tryb 'Nauczyciel Patrzy' (Panic Mode)")
                                    .bold()
                                Text("Głośność w górę x2 / Dwu-klik lewy róg")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }

                Section(header: Text("Szybkie Zakładki")) {
                    Link(destination: URL(string: "https://www.testportal.pl")!) {
                        Label("Testportal.pl", systemImage: "checkmark.shield.fill")
                    }
                    Link(destination: URL(string: "https://www.google.com")!) {
                        Label("Google Search", systemImage: "magnifyingglass")
                    }
                    Link(destination: URL(string: "https://chatgpt.com")!) {
                        Label("ChatGPT Portal", systemImage: "cpu")
                    }
                }
            }
            .navigationTitle("WhiteSolution WebSite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zamknij") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func triggerPanicMode() {
        triggerPanic()
    }
}
