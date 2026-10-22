import SwiftUI
import WebKit

// MARK: - 2026 Cyber Aesthetic Color Palette

private extension Color {
    static let oledBlack = Color(red: 0.02, green: 0.02, blue: 0.04)
    static let glassSurface = Color(red: 0.07, green: 0.09, blue: 0.16).opacity(0.85)
    static let neonCyan = Color(red: 0.15, green: 0.78, blue: 1.0)          // #26C6FF
    static let neonPurple = Color(red: 0.65, green: 0.35, blue: 1.0)        // #A659FF
    static let neonGreen = Color(red: 0.18, green: 0.95, blue: 0.60)        // #2EF299
    static let neonRed = Color(red: 1.0, green: 0.22, blue: 0.38)           // #FF3860
    static let textBright = Color.white
    static let textMuted = Color(white: 0.60)
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

    // Splash Screen State
    @State private var showSplash: Bool = true
    @State private var splashOpacity: Double = 1.0
    @State private var splashScale: CGFloat = 0.88
    @State private var splashGlow: Bool = false

    public enum NotificationState {
        case activatedAI
        case deactivatedPanic
    }
    
    @State private var activeNotification: NotificationState? = nil
    
    private var activeTab: WebTab? {
        tabs.first(where: { $0.id == activeTabId }) ?? tabs.first
    }

    var body: some View {
        ZStack {
            Color.oledBlack.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 1. Neon loading line at top
                if activeTab?.isLoading == true {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(.neonCyan)
                        .frame(height: 2)
                        .transition(.opacity)
                }
                
                // 2. Full-bleed WebView + Dynamic Status Island
                ZStack(alignment: .top) {
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
                    
                    // Floating Dynamic Island Capsule (Status Indicator)
                    topDynamicPill
                        .padding(.top, 8)
                }
                
                // Invisible double-tap gesture zone (safety switch)
                Color.clear
                    .contentShape(Rectangle())
                    .frame(height: 14)
                    .onTapGesture(count: 2) {
                        toggleAIState()
                    }
                
                // 3. Futuristic Floating Dock
                floatingDock
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }
            
            // 4. Splash Screen Overlay
            if showSplash {
                splashScreenOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let first = tabs.first {
                activeTabId = first.id
            }
            AIService.shared.apiKey = apiKey
            volumeObserver.startObserving()
            startSplashAnimation()
        }
        .onReceive(volumeObserver.$lastTriggeredAction) { action in
            guard let action = action else { return }
            switch action {
            case .triggerAI:
                // 2x głośność w dół działa jako przełącznik (WŁĄCZ / WYŁĄCZ)
                toggleAIState()
            case .triggerPanic:
                // 2x głośność w górę = bezwarunkowy Panic Mode
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
    
    // MARK: - Splash Screen
    
    private var splashScreenOverlay: some View {
        ZStack {
            Color.oledBlack.ignoresSafeArea()
            
            // Monochrome Ambient Specular Glow
            RadialGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.02), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()
            
            VStack(spacing: 22) {
                // Logo z pobranych (white_solution_transparent.png)
                if let uiImage = UIImage(named: "SplashLogo") ?? (Bundle.main.path(forResource: "white_solution_transparent", ofType: "png").flatMap { UIImage(contentsOfFile: $0) }) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260, maxHeight: 150)
                        .shadow(color: Color.white.opacity(splashGlow ? 0.35 : 0.08), radius: splashGlow ? 24 : 8)
                } else {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 68, weight: .ultraLight))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 6) {
                    Text("WHITE SOLUTION")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .tracking(6)
                        .foregroundColor(.white)
                    
                    Text("STEALTH RUNTIME 2026")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(Color.white.opacity(0.65))
                }
                
                // Micro-loader capsule (pure monochrome)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 140, height: 3)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: splashGlow ? 140 : 20, height: 3)
                }
            }
            .scaleEffect(splashScale)
            .opacity(splashOpacity)
        }
        .transition(.opacity)
        .zIndex(999)
        .onTapGesture {
            dismissSplash()
        }
    }
    
    private func startSplashAnimation() {
        withAnimation(.easeOut(duration: 1.0)) {
            splashScale = 1.0
            splashGlow = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            dismissSplash()
        }
    }
    
    private func dismissSplash() {
        withAnimation(.easeInOut(duration: 0.45)) {
            splashOpacity = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            showSplash = false
        }
    }
    
    // MARK: - Top Dynamic Island Pill
    
    private var topDynamicPill: some View {
        Group {
            if let notif = activeNotification {
                HStack(spacing: 8) {
                    Circle()
                        .fill(notif == .activatedAI ? Color.neonGreen : Color.neonRed)
                        .frame(width: 7, height: 7)
                        .shadow(color: (notif == .activatedAI ? Color.neonGreen : Color.neonRed).opacity(0.9), radius: 6)
                    
                    Text(notif == .activatedAI ? "AI ACTIVE" : "PANIC MODE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .background(Color.black.opacity(0.65))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [(notif == .activatedAI ? Color.neonGreen : Color.neonRed).opacity(0.6), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: (notif == .activatedAI ? Color.neonGreen : Color.neonRed).opacity(0.3), radius: 12)
                .transition(.asymmetric(insertion: .scale(scale: 0.8).combined(with: .opacity), removal: .opacity))
            } else if isAIActive {
                // Dyskretny status aktywnego asystenta
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.neonGreen)
                        .frame(width: 5, height: 5)
                        .shadow(color: Color.neonGreen.opacity(0.8), radius: 4)
                    Text("AI")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .background(Color.black.opacity(0.4))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.neonGreen.opacity(0.3), lineWidth: 0.5)
                )
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: activeNotification)
        .animation(.easeInOut(duration: 0.3), value: isAIActive)
    }
    
    // MARK: - 2026 Floating Dock
    
    private var floatingDock: some View {
        HStack(spacing: 8) {
            // Back Button
            dockButton(icon: "chevron.left", disabled: activeTab?.webView.canGoBack != true) {
                activeTab?.webView.goBack()
            }
            
            // Forward Button
            dockButton(icon: "chevron.right", disabled: activeTab?.webView.canGoForward != true) {
                activeTab?.webView.goForward()
            }
            
            // Minimalist URL Capsule
            urlCapsule
                .frame(maxWidth: .infinity)
            
            // Tabs Pill
            Button {
                showTabManager = true
            } label: {
                Text("\(tabs.count)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
            }
            
            // Settings / Features
            dockButton(icon: "ellipsis", disabled: false) {
                showFeatureMenu = true
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(Color.glassSurface)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.neonCyan.opacity(0.2), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 6)
    }
    
    private func dockButton(icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(disabled ? Color.textMuted.opacity(0.3) : .textBright)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.04))
                .clipShape(Circle())
        }
        .disabled(disabled)
    }
    
    // MARK: - URL Capsule
    
    private var urlCapsule: some View {
        HStack(spacing: 6) {
            if !isEditingURL {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.neonCyan)
            }
            
            if isEditingURL {
                TextField("Wpisz adres...", text: $urlInput, onCommit: {
                    loadURL(urlInput)
                    isEditingURL = false
                })
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            } else {
                Text(displayHost)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.textMuted)
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
                        .font(.system(size: 12))
                        .foregroundColor(.textMuted)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    private var displayHost: String {
        guard let url = URL(string: urlInput), let host = url.host else {
            return urlInput
        }
        return host
    }
    
    // MARK: - Actions & Toggles
    
    private func toggleAIState() {
        if isAIActive {
            triggerPanicMode()
        } else {
            triggerAIAnalysis()
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
        isAIActive = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showNotification(.activatedAI)
        if let tab = activeTab {
            tab.statusMessage = "Analizuję pytanie..."
            StealthWebView.triggerAIAnalysis(webView: tab.webView)
        }
    }

    private func triggerPanicMode() {
        isAIActive = false
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        showNotification(.deactivatedPanic)
        if let tab = activeTab {
            tab.statusMessage = "TRYB DYSKRETNY"
            StealthWebView.triggerPanicMode(webView: tab.webView)
        }
    }

    private func showNotification(_ state: NotificationState) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            activeNotification = state
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                if activeNotification == state {
                    activeNotification = nil
                }
            }
        }
    }
}

// MARK: - 2026 Feature Menu View

struct FeatureMenuView: View {
    @Environment(\.dismiss) var dismiss
    var triggerAI: () -> Void
    var triggerPanic: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.oledBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        sectionHeader("Sterowanie Asystentem")
                        
                        featureCard(
                            icon: "bolt.fill",
                            iconColor: .neonCyan,
                            title: "Przełącznik Asystenta (Włącz / Wyłącz)",
                            subtitle: "2x głośność w dół lub dwu-klik dolnego paska"
                        ) {
                            dismiss()
                            triggerAI()
                        }
                        
                        featureCard(
                            icon: "eye.slash.fill",
                            iconColor: .neonRed,
                            title: "Natychmiastowy Panic Mode",
                            subtitle: "2x głośność w górę (czyszczenie i blokada)"
                        ) {
                            dismiss()
                            triggerPanic()
                        }
                        
                        sectionHeader("Portale Egzaminacyjne")
                        
                        quickLink(icon: "checkmark.shield.fill", color: .neonGreen, title: "Testportal.pl", url: "https://www.testportal.pl")
                        quickLink(icon: "magnifyingglass", color: .neonCyan, title: "Google", url: "https://www.google.com")
                        quickLink(icon: "brain.head.profile", color: .neonPurple, title: "Google AI Studio (Darmowy klucz Gemini)", url: "https://aistudio.google.com/app/apikey")
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Centrum Operacyjne")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") {
                        dismiss()
                    }
                    .foregroundColor(.neonCyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.textMuted)
                .tracking(1.4)
            Spacer()
        }
        .padding(.top, 6)
    }
    
    private func featureCard(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 42, height: 42)
                    .background(iconColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(iconColor.opacity(0.25), lineWidth: 0.8)
                    )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textMuted.opacity(0.4))
            }
            .padding(14)
            .background(Color.glassSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }
    
    private func quickLink(icon: String, color: Color, title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundColor(color)
                    .frame(width: 36, height: 36)
                    .background(color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.textMuted.opacity(0.4))
            }
            .padding(12)
            .background(Color.glassSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }
}
