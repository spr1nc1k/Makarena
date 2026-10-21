import SwiftUI

private extension Color {
    static let oledBlack = Color(red: 0.02, green: 0.02, blue: 0.04)
    static let glassSurface = Color(red: 0.07, green: 0.09, blue: 0.16).opacity(0.85)
    static let neonCyan = Color(red: 0.15, green: 0.78, blue: 1.0)
    static let neonPurple = Color(red: 0.65, green: 0.35, blue: 1.0)
    static let neonGreen = Color(red: 0.18, green: 0.95, blue: 0.60)
    static let textBright = Color.white
    static let textMuted = Color(white: 0.60)
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("gemini_api_key") private var apiKey: String = ""

    @StateObject private var updateService = UpdateService.shared
    @State private var serverURLInput: String = UpdateService.shared.serverURL

    var body: some View {
        NavigationView {
            ZStack {
                Color.oledBlack.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // AI Engine Section
                        settingsSection(title: "Silnik AI i Widzenie (Vision)") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.neonCyan)
                                        .font(.system(size: 16))
                                    Text("Automatyczna Pula Publiczna")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                Text("Aplikacja automatycznie przechodzi po puli serwerów do rozwiązywania pytań tekstowych.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.textMuted)
                                
                                Divider().background(Color.white.opacity(0.08))
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Klucz Google Gemini 2.0 Flash Vision (Zalecany):")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.neonCyan)
                                    Text("Daje 100% poprawności, brak limitów czasowych oraz natywne widzenie wykresów, tabel i wzorców graficznych.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.textMuted)
                                    
                                    SecureField("AIzaSy...", text: $apiKey)
                                        .font(.system(size: 13, design: .monospaced))
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .padding(12)
                                        .background(Color.white.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                        )
                                    
                                    Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "arrow.up.right.square")
                                            Text("Pobierz darmowy klucz z Google AI Studio")
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.neonCyan)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                        
                        // Update Section
                        settingsSection(title: "Aktualizacje Stealth OTA") {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Adres Repozytorium")
                                        .font(.system(size: 11))
                                        .foregroundColor(.textMuted)
                                    TextField("https://raw.githubusercontent.com/spr1nc1k/Makarena/main", text: $serverURLInput)
                                        .font(.system(size: 12, design: .monospaced))
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                        .padding(12)
                                        .background(Color.white.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                                        )
                                }
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Wersja aplikacji")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text("Bieżąca: v\(updateService.currentAppVersion)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.textMuted)
                                        if !updateService.latestVersion.isEmpty {
                                            Text("Dostępna: v\(updateService.latestVersion)")
                                                .font(.system(size: 12))
                                                .foregroundColor(updateService.updateAvailable ? .neonGreen : .textMuted)
                                        }
                                    }
                                    Spacer()

                                    if updateService.isChecking {
                                        ProgressView()
                                            .tint(.neonCyan)
                                    } else {
                                        Button {
                                            updateService.serverURL = serverURLInput
                                            updateService.checkForUpdates { _, _ in }
                                        } label: {
                                            Text("Sprawdź")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(Color.neonCyan)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }

                                if !updateService.updateStatusMessage.isEmpty {
                                    Text(updateService.updateStatusMessage)
                                        .font(.system(size: 12))
                                        .foregroundColor(updateService.updateAvailable ? .neonGreen : .textMuted)
                                }

                                if updateService.updateAvailable {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Dziennik zmian:")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(updateService.changelog)
                                            .font(.system(size: 12))
                                            .foregroundColor(.textMuted)

                                        Button {
                                            updateService.performUpdate()
                                        } label: {
                                            Text("Zainstaluj aktualizację")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(Color.neonGreen)
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Ustawienia Systemu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        dismiss()
                    }
                    .foregroundColor(.neonCyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.textMuted)
                .tracking(1.4)
                .padding(.horizontal, 4)

            content()
                .padding(16)
                .background(Color.glassSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        }
    }
}
