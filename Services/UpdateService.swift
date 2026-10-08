import Foundation
import UIKit
import Combine

/// Serwis odpowiedzialny za sprawdzanie aktualizacji aplikacji oraz pobieranie najnowszych skryptów bypassu.
public class UpdateService: ObservableObject {
    public static let shared = UpdateService()
    
    @Published public var isChecking: Bool = false
    @Published public var updateAvailable: Bool = false
    @Published public var latestVersion: String = ""
    @Published public var changelog: String = ""
    @Published public var updateStatusMessage: String = ""
    @Published public var downloadURL: String = ""
    @Published public var manifestURL: String = ""
    
    // Konfigurowalny adres serwera aktualizacji
    public var serverURL: String {
        get {
            UserDefaults.standard.string(forKey: "update_server_url") ?? "https://raw.githubusercontent.com/spr1nc1k/Makarena/main"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "update_server_url")
        }
    }
    
    public var currentAppVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private init() {}
    
    public struct UpdateManifest: Codable {
        public let version: String
        public let downloadUrl: String?
        public let manifestUrl: String?
        public let changelog: String?
        public let scripts: ScriptFiles?
        
        public struct ScriptFiles: Codable {
            public let testportalBypass: String?
            public let aiInjector: String?
        }
    }
    
    /// Sprawdzenie dostępności nowej wersji na serwerze
    public func checkForUpdates(completion: @escaping (Bool, String) -> Void) {
        let cleanServer = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = cleanServer.hasSuffix("/") ? "\(cleanServer)version.json" : "\(cleanServer)/version.json"
        
        guard let url = URL(string: endpoint) else {
            completion(false, "Nieprawidłowy adres serwera aktualizacji.")
            return
        }
        
        DispatchQueue.main.async {
            self.isChecking = true
            self.updateStatusMessage = "Sprawdzanie dostępności aktualizacji..."
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 8.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isChecking = false
                
                if let error = error {
                    let msg = "Błąd połączenia z serwerem: \(error.localizedDescription)"
                    self?.updateStatusMessage = msg
                    completion(false, msg)
                    return
                }
                
                guard let data = data else {
                    let msg = "Otrzymano puste dane z serwera."
                    self?.updateStatusMessage = msg
                    completion(false, msg)
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let manifest = try decoder.decode(UpdateManifest.self, from: data)
                    
                    self?.latestVersion = manifest.version
                    self?.changelog = manifest.changelog ?? "Brak opisu zmian."
                    self?.downloadURL = manifest.downloadUrl ?? ""
                    self?.manifestURL = manifest.manifestUrl ?? ""
                    
                    // Porównanie wersji
                    if self?.isVersionNewer(manifest.version, current: self?.currentAppVersion ?? "1.0.0") == true {
                        self?.updateAvailable = true
                        let msg = "Dostępna nowa wersja v\(manifest.version)!"
                        self?.updateStatusMessage = msg
                        completion(true, msg)
                    } else {
                        // Pobieramy ewentualnie zaktualizowane skrypty bypass bez konieczności re-instalacji IPA
                        if let scripts = manifest.scripts {
                            self?.downloadUpdatedScripts(scripts: scripts)
                        }
                        self?.updateAvailable = false
                        let msg = "Aplikacja jest aktualna (v\(self?.currentAppVersion ?? "1.0.0"))."
                        self?.updateStatusMessage = msg
                        completion(false, msg)
                    }
                } catch {
                    let msg = "Nieprawidłowy format pliku manifestu version.json."
                    self?.updateStatusMessage = msg
                    completion(false, msg)
                }
            }
        }.resume()
    }
    
    /// Pobieranie najnowszych skryptów JS bezpośrednio z serwera (Hot-Reload)
    private func downloadUpdatedScripts(scripts: UpdateManifest.ScriptFiles) {
        let fileManager = FileManager.default
        guard let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let scriptsDir = docsDir.appendingPathComponent("Scripts")
        
        try? fileManager.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        
        if let bypassUrlStr = scripts.testportalBypass, let url = URL(string: bypassUrlStr) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data {
                    let target = scriptsDir.appendingPathComponent("testportal_bypass.js")
                    try? data.write(to: target)
                    print("[UpdateService] Zaktualizowano skrypt testportal_bypass.js w dokumentach.")
                }
            }.resume()
        }
        
        if let aiUrlStr = scripts.aiInjector, let url = URL(string: aiUrlStr) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data {
                    let target = scriptsDir.appendingPathComponent("ai_injector.js")
                    try? data.write(to: target)
                    print("[UpdateService] Zaktualizowano skrypt ai_injector.js w dokumentach.")
                }
            }.resume()
        }
    }
    
    /// Wywołanie instalacji nowej wersji (Enterprise OTA / AltStore / TrollStore URL)
    public func performUpdate() {
        var targetURLString = manifestURL.isEmpty ? downloadURL : manifestURL
        if targetURLString.isEmpty {
            targetURLString = "\(serverURL)/Makarena.ipa"
        }
        
        guard let url = URL(string: targetURLString) else { return }
        
        DispatchQueue.main.async {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    
    /// Porównanie wersji w formacie SemVer (np. 1.1.0 vs 1.0.0)
    private func isVersionNewer(_ remote: String, current: String) -> Bool {
        return remote.compare(current, options: .numeric) == .orderedDescending
    }
}
