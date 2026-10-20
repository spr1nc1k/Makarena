import SwiftUI
import WebKit

// MARK: - Color Palette

private extension Color {
    static let mkNavy = Color(red: 0.039, green: 0.055, blue: 0.102)       // #0A0E1A
    static let mkSurface = Color(red: 0.067, green: 0.082, blue: 0.141)    // #111524
    static let mkAccent = Color(red: 0.310, green: 0.557, blue: 1.0)       // #4F8EFF
    static let mkPurple = Color(red: 0.482, green: 0.361, blue: 1.0)       // #7B5CFF
    static let mkGreen = Color(red: 0.204, green: 0.827, blue: 0.600)      // #34D399
    static let mkRed = Color(red: 1.0, green: 0.278, blue: 0.341)          // #FF4757
    static let mkTextPrimary = Color.white
    static let mkTextSecondary = Color(white: 0.55)
}

// MARK: - ContentView

struct ContentView: View {
    @State private var tabs: [WebTab] = [WebTab(urlString: "https://www.testportal.pl")]
    @State private var activeTabId: UUID = UUID()
    
    @State private var urlInput: String = "https://www.testportal.pl"
    @State private var isEditingURL: Bool = false
    @State private var showSettings: Bool = false
    @State private var showTabManager: Bool = false
    @State private var showFeatureMenu: Bool = false
    
    @StateObject private var volumeObserver = VolumeKeyObserver.shared
    @StateObject private var updateService = UpdateService.shared
    @AppStorage("gemini_api_key") private var apiKey: String = ""
    @AppStorage("makarena_ai_active") private var isAIActive: Bool = false

    public enum NotificationState {
        case activatedAI
        case deactivatedPanic
    }
    
    @State private var activeNotification: NotificationState? = nil
    @State private var fabPulse: Bool = false
    
    private var activeTab: WebTab? {
        tabs.first(where: { $0.id == activeTabId }) ?? tabs.first
    }

    var body: some View {
        ZStack {
            Color.mkNavy.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Progress bar at top
                if activeTab?.isLoading == true {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(.mkAccent)
                        .frame(height: 2)
                        .transition(.opacity)
                }
                
                // 2. WebView — full bleed
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
                            isAIActive: isAIActive,
                            webView: tab.webView
                        )
                        .id(tab.id)
                    }
                    
                    // 3. Notification overlay
                    if let notification = activeNotification {
                        notificationBadge(notification)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                
                // Gesture zone
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
                
                // 4. Bottom toolbar
                bottomToolbar
            }
            
            // 5. FAB — bottom right, above toolbar
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    fabButton
                        .padding(.trailing, 16)
                        .padding(.bottom, 70)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let first = tabs.first {
                activeTabId = first.id
            }
            AIService.shared.apiKey = apiKey
            volumeObserver.startObserving()
            startFabPulse()
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
        .alert("Dostępna aktualizacja v\(updateService.latestVersion)", isPresented: $updateService.showUpdateAlert) {
            Button("Zaktualizuj") {
                updateService.performUpdate()
            }
            Button("Później", role: .cancel) {}
        } message: {
            Text(updateService.changelog)
        }
    }
    
    // MARK: - Bottom Toolbar
    
    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            // Back
            toolbarButton(icon: "chevron.left", disabled: activeTab?.webView.canGoBack != true) {
                activeTab?.webView.goBack()
            }
            
            // Forward
            toolbarButton(icon: "chevron.right", disabled: activeTab?.webView.canGoForward != true) {
                activeTab?.webView.goForward()
            }
            
            // URL bar
            urlBar
                .frame(maxWidth: .infinity)
            
            // Tab count
            Button {
                showTabManager = true
            } label: {
                Text("\(tabs.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.mkAccent)
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.mkAccent, lineWidth: 1.5)
                    )
            }
            .padding(.horizontal, 6)
            
            // Menu
            toolbarButton(icon: "line.3.horizontal", disabled: false) {
                showFeatureMenu = true
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            Color.mkSurface
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.white.opacity(0.08)),
                    alignment: .top
                )
        )
    }
    
    private func toolbarButton(icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(disabled ? Color.mkTextSecondary.opacity(0.3) : .mkTextPrimary)
                .frame(width: 40, height: 40)
        }
        .disabled(disabled)
    }
    
    // MARK: - URL Bar
    
    private var urlBar: some View {
        HStack(spacing: 6) {
            if !isEditingURL {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.mkGreen)
            }
            
            if isEditingURL {
                TextField("Wpisz adres lub szukaj...", text: $urlInput, onCommit: {
                    loadURL(urlInput)
                    isEditingURL = false
                })
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.mkTextPrimary)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            } else {
                Text(displayHost)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.mkTextSecondary)
                    .lineLimit(1)
                    .onTapGesture {
                        isEditingURL = true
                    }
            }
            
            Spacer(minLength: 0)
            
            if isEditingURL {
                Button {
                    isEditingURL = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.mkTextSecondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    private var displayHost: String {
        guard let url = URL(string: urlInput), let host = url.host else {
            return urlInput
        }
        return host
    }
    
    // MARK: - FAB
    
    private var fabButton: some View {
        Button {
            triggerAIAnalysis()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.mkAccent, .mkPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: .mkAccent.opacity(0.4), radius: fabPulse ? 14 : 6, x: 0, y: 4)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(fabPulse ? 1.08 : 1.0)
        }
    }
    
    private func startFabPulse() {
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
            fabPulse = true
        }
    }
    
    // MARK: - Notification Badge
    
    private func notificationBadge(_ notification: NotificationState) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(notification == .activatedAI ? Color.mkGreen : Color.mkRed)
                .frame(width: 8, height: 8)
                .shadow(color: (notification == .activatedAI ? Color.mkGreen : Color.mkRed).opacity(0.8), radius: 4)
            Text(notification == .activatedAI ? "Włączone" : "Wyłączone")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.5))
        .cornerRadius(12)
        .padding(.top, 10)
        .padding(.trailing, 10)
        .allowsHitTesting(false)
    }
    
    // MARK: - Actions

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
        isAIActive = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showNotification(.activatedAI)
        if let tab = activeTab {
            tab.statusMessage = "Wywoływanie AI..."
            StealthWebView.triggerAIAnalysis(webView: tab.webView)
        }
    }

    private func triggerPanicMode() {
        isAIActive = false
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        showNotification(.deactivatedPanic)
        if let tab = activeTab {
            tab.statusMessage = "TRYB NAUCZYCIEL PATRZY"
            StealthWebView.triggerPanicMode(webView: tab.webView)
        }
    }

    private func showNotification(_ state: NotificationState) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            activeNotification = state
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if activeNotification == state {
                    activeNotification = nil
                }
            }
        }
    }
}

// MARK: - Feature Menu View

struct FeatureMenuView: View {
    @Environment(\.dismiss) var dismiss
    var triggerAI: () -> Void
    var triggerPanic: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.mkNavy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Actions section
                        sectionHeader("Akcje")
                        
                        featureCard(
                            icon: "sparkles",
                            iconColor: .mkAccent,
                            title: "Wyznacz Odpowiedź (AI Solve)",
                            subtitle: "Głośność w dół x2 / Dwu-klik prawy róg"
                        ) {
                            dismiss()
                            triggerAI()
                        }
                        
                        featureCard(
                            icon: "eye.slash.fill",
                            iconColor: .mkRed,
                            title: "Tryb 'Nauczyciel Patrzy' (Panic Mode)",
                            subtitle: "Głośność w górę x2 / Dwu-klik lewy róg"
                        ) {
                            dismiss()
                            triggerPanicMode()
                        }
                        
                        // Quick links section
                        sectionHeader("Szybkie Zakładki")
                        
                        quickLink(icon: "checkmark.shield.fill", color: .mkGreen, title: "Testportal.pl", url: "https://www.testportal.pl")
                        quickLink(icon: "magnifyingglass", color: .mkAccent, title: "Google Search", url: "https://www.google.com")
                        quickLink(icon: "cpu", color: .mkPurple, title: "ChatGPT Portal", url: "https://chatgpt.com")
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Funkcje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zamknij") {
                        dismiss()
                    }
                    .foregroundColor(.mkAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.mkTextSecondary)
                .tracking(1.2)
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private func featureCard(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.mkTextPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.mkTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.mkTextSecondary.opacity(0.5))
            }
            .padding(14)
            .background(Color.mkSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }
    
    private func quickLink(icon: String, color: Color, title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.mkTextPrimary)
                
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.mkTextSecondary.opacity(0.4))
            }
            .padding(12)
            .background(Color.mkSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }

    private func triggerPanicMode() {
        triggerPanic()
    }
}
