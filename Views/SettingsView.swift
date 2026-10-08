import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("gemini_api_key") private var apiKey: String = ""

    @StateObject private var updateService = UpdateService.shared
    @State private var serverURLInput: String = UpdateService.shared.serverURL

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Silnik AI (100% Darmowy)")) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Automatyczna Pula Darmowych Serwerów AI")
                                .bold()
                        }
                        Text("Aplikacja automatycznie przechodzi po puli bezpłatnych serwerów (Pollinations, LLM7, OVH, Gemini). Użytkownik nie musi niczego wybierać ani konfigurować.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Opcjonalny własny Klucz Gemini API (darmowy z Google AI Studio):")
                            .font(.caption)
                            .foregroundColor(.gray)
                        SecureField("Wklej opcjonalny klucz API (AIzaSy...)", text: $apiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }

                Section(header: Text("Automatyczne Aktualizacje")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Adres Serwera Aktualizacji (GitHub / Cloudflare)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("https://raw.githubusercontent.com/spr1nc1k/Makarena/main", text: $serverURLInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    HStack {
                        VStack(alignment: .leading) {
                            Text("Wersja aplikacji")
                                .bold()
                            Text("Bieżąca: v\(updateService.currentAppVersion)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if !updateService.latestVersion.isEmpty {
                                Text("Najnowsza: v\(updateService.latestVersion)")
                                    .font(.caption)
                                    .foregroundColor(updateService.updateAvailable ? .green : .gray)
                            }
                        }
                        Spacer()

                        if updateService.isChecking {
                            ProgressView()
                        } else {
                            Button("Sprawdź") {
                                updateService.serverURL = serverURLInput
                                updateService.checkForUpdates { _, _ in }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if !updateService.updateStatusMessage.isEmpty {
                        Text(updateService.updateStatusMessage)
                            .font(.footnote)
                            .foregroundColor(updateService.updateAvailable ? .green : .secondary)
                    }

                    if updateService.updateAvailable {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lista zmian (Changelog):")
                                .font(.caption)
                                .bold()
                            Text(updateService.changelog)
                                .font(.caption)
                                .foregroundColor(.primary)

                            Button(action: {
                                updateService.performUpdate()
                            }) {
                                HStack {
                                    Image(systemName: "arrow.down.app.fill")
                                    Text("Zaktualizuj Teraz")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(header: Text("Instrukcja przycisków głośności")) {
                    HStack {
                        Image(systemName: "speaker.wave.1.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Głośność w dół")
                                .bold()
                            Text("Włącza AI Solve (Wyświetla powiadomienie 'Włączone')")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.red)
                        VStack(alignment: .leading) {
                            Text("Głośność w górę")
                                .bold()
                            Text("Włącza Panic Mode (Wyświetla powiadomienie 'Wyłączone')")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
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
                }
            }
        }
    }
}
