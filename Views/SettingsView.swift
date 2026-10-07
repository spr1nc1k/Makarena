import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("gemini_api_key") private var apiKey: String = ""
    @AppStorage("api_provider") private var selectedProvider: String = AIService.APIProvider.autoFreePool.rawValue

    @StateObject private var updateService = UpdateService.shared
    @State private var serverURLInput: String = UpdateService.shared.serverURL

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Darmowe Silniki AI (12 Dostawców)")) {
                    Picker("Dostawca AI", selection: $selectedProvider) {
                        ForEach(AIService.APIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider.rawValue)
                        }
                    }
                    
                    if selectedProvider != AIService.APIProvider.autoFreePool.rawValue &&
                       selectedProvider != AIService.APIProvider.pollinations.rawValue &&
                       selectedProvider != AIService.APIProvider.llm7.rawValue &&
                       selectedProvider != AIService.APIProvider.ovh.rawValue {
                        SecureField("Wprowadź swój Klucz API", text: $apiKey)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        Text("✅ W wybranym trybie AI działa 100% darmowo i bez rejestracji!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Section(header: Text("Automatyczne Aktualizacje")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Adres Serwera Aktualizacji (SSH/HTTP)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("http://192.168.50.235:8000", text: $serverURLInput)
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
                                Text("Najnowsza na serwerze: v\(updateService.latestVersion)")
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
                                updateService.checkForUpdates { available, msg in
                                    // Status jest aktualizowany w obiekcie UpdateService
                                }
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
                            Text("Głośność w dół (x2)")
                                .bold()
                            Text("Uruchamia analizę pytania i wyznacza odpowiedź")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.red)
                        VStack(alignment: .leading) {
                            Text("Głośność w górę (x2)")
                                .bold()
                            Text("Tryb 'Nauczyciel patrzy' (natychmiast ukrywa odpowiedzi)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Section(header: Text("Informacja o omijaniu Testportal")) {
                    Text("System automatycznie neutralizuje zdarzenia blur, visibilitychange i pagehide, zapobiegając rejestrowaniu opuszczenia karty.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("WhiteSolution WebSite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") {
                        AIService.shared.apiKey = apiKey
                        if let provider = AIService.APIProvider(rawValue: selectedProvider) {
                            AIService.shared.apiProvider = provider
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
