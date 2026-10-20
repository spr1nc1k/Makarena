import SwiftUI

private extension Color {
    static let mkNavy = Color(red: 0.039, green: 0.055, blue: 0.102)
    static let mkSurface = Color(red: 0.067, green: 0.082, blue: 0.141)
    static let mkAccent = Color(red: 0.310, green: 0.557, blue: 1.0)
    static let mkPurple = Color(red: 0.482, green: 0.361, blue: 1.0)
    static let mkGreen = Color(red: 0.204, green: 0.827, blue: 0.600)
    static let mkRed = Color(red: 1.0, green: 0.278, blue: 0.341)
    static let mkTextPrimary = Color.white
    static let mkTextSecondary = Color(white: 0.55)
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("gemini_api_key") private var apiKey: String = ""

    @StateObject private var updateService = UpdateService.shared
    @State private var serverURLInput: String = UpdateService.shared.serverURL

    var body: some View {
        NavigationView {
            ZStack {
                Color.mkNavy.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // AI Engine Section
                        settingsSection(title: "Silnik AI (100% Darmowy)") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.mkGreen)
                                        .font(.system(size: 16))
                                    Text("Automatyczna Pula Darmowych Serwerów AI")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.mkTextPrimary)
                                }
                                
                                Text("Aplikacja automatycznie przechodzi po puli bezpłatnych serwerów. Użytkownik nie musi niczego konfigurować.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.mkTextSecondary)
                                
                                Divider().background(Color.white.opacity(0.08))
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Własny darmowy Klucz Gemini API (Zalecany):")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.mkTextPrimary)
                                    Text("Daje 0ms opóźnienia, brak limitów 30s oraz pełną analizę ilustracji i zadań ze zdjęciami.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.mkTextSecondary)
                                    
                                    SecureField("Wklej klucz API (AIzaSy...)", text: $apiKey)
                                        .font(.system(size: 13, design: .monospaced))
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .padding(10)
                                        .background(Color.mkNavy)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                        )
                                    
                                    Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "arrow.up.right.square")
                                            Text("Otwórz Google AI Studio i pobierz darmowy klucz")
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.mkAccent)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                        }
                        
                        // Update Section
                        settingsSection(title: "Automatyczne Aktualizacje") {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Adres Serwera Aktualizacji (GitHub / Cloudflare)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.mkTextSecondary)
                                    TextField("https://raw.githubusercontent.com/spr1nc1k/Makarena/main", text: $serverURLInput)
                                        .font(.system(size: 12, design: .monospaced))
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .padding(10)
                                        .background(Color.mkNavy)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                        )
                                }
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Wersja aplikacji")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.mkTextPrimary)
                                        Text("Bieżąca: v\(updateService.currentAppVersion)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.mkTextSecondary)
                                        if !updateService.latestVersion.isEmpty {
                                            Text("Najnowsza: v\(updateService.latestVersion)")
                                                .font(.system(size: 12))
                                                .foregroundColor(updateService.updateAvailable ? .mkGreen : .mkTextSecondary)
                                        }
                                    }
                                    Spacer()

                                    if updateService.isChecking {
                                        ProgressView()
                                            .tint(.mkAccent)
                                    } else {
                                        Button {
                                            updateService.serverURL = serverURLInput
                                            updateService.checkForUpdates { _, _ in }
                                        } label: {
                                            Text("Sprawdź")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.mkNavy)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Color.mkAccent)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }

                                if !updateService.updateStatusMessage.isEmpty {
                                    Text(updateService.updateStatusMessage)
                                        .font(.system(size: 12))
                                        .foregroundColor(updateService.updateAvailable ? .mkGreen : .mkTextSecondary)
                                }

                                if updateService.updateAvailable {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Lista zmian (Changelog):")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.mkTextPrimary)
                                        Text(updateService.changelog)
                                            .font(.system(size: 12))
                                            .foregroundColor(.mkTextSecondary)

                                        Button {
                                            updateService.performUpdate()
                                        } label: {
                                            HStack {
                                                Image(systemName: "arrow.down.app.fill")
                                                Text("Zaktualizuj Teraz")
                                            }
                                            .font(.system(size: 14, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                LinearGradient(colors: [.mkAccent, .mkPurple], startPoint: .leading, endPoint: .trailing)
                                            )
                                            .foregroundColor(.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Volume instructions
                        settingsSection(title: "Instrukcja przycisków głośności") {
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "speaker.wave.1.fill")
                                        .foregroundColor(.mkGreen)
                                        .frame(width: 32, height: 32)
                                        .background(Color.mkGreen.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Głośność w dół")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.mkTextPrimary)
                                        Text("Włącza AI Solve (Wyświetla powiadomienie 'Włączone')")
                                            .font(.system(size: 11))
                                            .foregroundColor(.mkTextSecondary)
                                    }
                                    Spacer()
                                }
                                
                                Divider().background(Color.white.opacity(0.06))
                                
                                HStack(spacing: 12) {
                                    Image(systemName: "speaker.wave.3.fill")
                                        .foregroundColor(.mkRed)
                                        .frame(width: 32, height: 32)
                                        .background(Color.mkRed.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Głośność w górę")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.mkTextPrimary)
                                        Text("Włącza Panic Mode (Wyświetla powiadomienie 'Wyłączone')")
                                            .font(.system(size: 11))
                                            .foregroundColor(.mkTextSecondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Ustawienia Makarena")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") {
                        AIService.shared.apiKey = apiKey
                        dismiss()
                    }
                    .foregroundColor(.mkAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Section Builder
    
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.mkTextSecondary)
                .tracking(1.2)
            
            content()
                .padding(16)
                .background(Color.mkSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        }
    }
}
