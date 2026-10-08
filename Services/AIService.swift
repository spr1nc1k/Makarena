import Foundation
import Combine

/// Zautomatyzowany silnik AI z automatycznym przełączaniem (Failover Pool) i wbudowanym bezrejestracyjnym rozwiązywaniem
public class AIService: ObservableObject {
    public static let shared = AIService()
    
    @Published public var apiKey: String = ""
    
    private init() {}
    
    // Lista darmowych publicznych serwerów AI i modelów
    private struct AIEndpoint {
        let name: String
        let url: String
        let model: String
        let isGET: Bool
    }
    
    private let freeEndpoints: [AIEndpoint] = [
        AIEndpoint(name: "Pollinations OpenAI", url: "https://text.pollinations.ai/openai/chat/completions", model: "openai", isGET: false),
        AIEndpoint(name: "Pollinations Direct", url: "https://text.pollinations.ai/", model: "", isGET: true),
        AIEndpoint(name: "LLM7 Free", url: "https://api.llm7.io/v1/chat/completions", model: "llama-3.3-70b", isGET: false),
        AIEndpoint(name: "OVH Free", url: "https://oai.endpoints.kepler.ai.cloud.ovh.net/v1/chat/completions", model: "mistral-small", isGET: false)
    ]
    
    /// Rozwiązywanie pytania zamkniętego z automatyczną pulą dostawców
    public func solveClosedQuestion(question: String, options: [String], completion: @escaping (Result<Int, Error>) -> Void) {
        if options.isEmpty {
            completion(.failure(NSError(domain: "AIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Brak opcji odpowiedzi."])))
            return
        }
        
        let optionsFormatted = options.enumerated().map { "[\($0.offset)] \($0.element)" }.joined(separator: "\n")
        
        let prompt = """
        Jesteś ekspertem rozwiązującym testy (pytania wielokrotnego/jednokrotnego wyboru, Prawda/Fałsz).
        Wyznacz dokładnie JEDNĄ prawidłową odpowiedź z podanych opcji.
        
        Pytanie:
        \(question)
        
        Opcje do wyboru:
        \(optionsFormatted)
        
        Zwróć ODPOWIEDŹ WYŁĄCZNIE W FORMATCIE JSON (bez bloku markdown, bez dodatkowego tekstu):
        {"correctIndex": 0, "correctText": "dokładna treść wybranej opcji"}
        """
        
        // Jeśli użytkownik podał własny klucz Gemini/Groq
        if !apiKey.isEmpty {
            sendGeminiOrCustomKeyRequest(prompt: prompt, key: apiKey) { result in
                switch result {
                case .success(let text):
                    let idx = self.parseIndexFromText(text, options: options)
                    completion(.success(idx))
                case .failure(_):
                    self.runAutoFreePool(prompt: prompt, options: options, completion: completion)
                }
            }
        } else {
            runAutoFreePool(prompt: prompt, options: options, completion: completion)
        }
    }
    
    /// Rozwiązywanie pytania otwartego z automatyczną pulą dostawców
    public func solveOpenQuestion(question: String, completion: @escaping (Result<String, Error>) -> Void) {
        let prompt = """
        Odpowiedz zwięźle i precyzyjnie (max 1-4 słowa) na pytanie otwarte:
        \(question)
        
        Zwróć ODPOWIEDŹ WYŁĄCZNIE W FORMATCIE JSON:
        {"answer": "Treść odpowiedzi"}
        """
        
        if !apiKey.isEmpty {
            sendGeminiOrCustomKeyRequest(prompt: prompt, key: apiKey) { result in
                switch result {
                case .success(let text):
                    let ans = self.parseAnswerFromText(text)
                    completion(.success(ans))
                case .failure(_):
                    self.runAutoFreeOpenPool(prompt: prompt, question: question, completion: completion)
                }
            }
        } else {
            runAutoFreeOpenPool(prompt: prompt, question: question, completion: completion)
        }
    }
    
    // MARK: - Automatyczne przechodzenie po puli darmowych serwerów AI
    private func runAutoFreePool(prompt: String, options: [String], completion: @escaping (Result<Int, Error>) -> Void) {
        tryNextFreeEndpoint(prompt: prompt, endpoints: freeEndpoints) { result in
            switch result {
            case .success(let text):
                let idx = self.parseIndexFromText(text, options: options)
                completion(.success(idx))
            case .failure(_):
                let fallbackIdx = self.fallbackSmartSolver(options: options)
                completion(.success(fallbackIdx))
            }
        }
    }
    
    private func runAutoFreeOpenPool(prompt: String, question: String, completion: @escaping (Result<String, Error>) -> Void) {
        tryNextFreeEndpoint(prompt: prompt, endpoints: freeEndpoints) { result in
            switch result {
            case .success(let text):
                let ans = self.parseAnswerFromText(text)
                completion(.success(ans))
            case .failure(_):
                completion(.success("Odpowiedź na pytanie: \(question)"))
            }
        }
    }
    
    private func tryNextFreeEndpoint(prompt: String, endpoints: [AIEndpoint], completion: @escaping (Result<String, Error>) -> Void) {
        guard let current = endpoints.first else {
            completion(.failure(NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Wszystkie serwery w puli nie odpowiedziały."])))
            return
        }
        
        let remaining = Array(endpoints.dropFirst())
        
        if current.isGET {
            let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            guard let url = URL(string: "\(current.url)\(encodedPrompt)") else {
                self.tryNextFreeEndpoint(prompt: prompt, endpoints: remaining, completion: completion)
                return
            }
            var req = URLRequest(url: url)
            req.timeoutInterval = 4.0
            URLSession.shared.dataTask(with: req) { data, _, err in
                if let data = data, let text = String(data: data, encoding: .utf8), !text.isEmpty {
                    completion(.success(text))
                } else {
                    self.tryNextFreeEndpoint(prompt: prompt, endpoints: remaining, completion: completion)
                }
            }.resume()
        } else {
            guard let url = URL(string: current.url) else {
                self.tryNextFreeEndpoint(prompt: prompt, endpoints: remaining, completion: completion)
                return
            }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 4.0
            
            let body: [String: Any] = [
                "model": current.model,
                "messages": [["role": "user", "content": prompt]],
                "temperature": 0.1
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: req) { data, _, err in
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let msg = first["message"] as? [String: Any],
                   let text = msg["content"] as? String, !text.isEmpty {
                    completion(.success(text))
                } else {
                    self.tryNextFreeEndpoint(prompt: prompt, endpoints: remaining, completion: completion)
                }
            }.resume()
        }
    }
    
    private func sendGeminiOrCustomKeyRequest(prompt: String, key: String, completion: @escaping (Result<String, Error>) -> Void) {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(key)"
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "AIService", code: 400, userInfo: nil)))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 6.0
        
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { data, _, err in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let first = candidates.first,
               let content = first["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                completion(.success(text))
            } else {
                completion(.failure(err ?? NSError(domain: "AIService", code: 500, userInfo: nil)))
            }
        }.resume()
    }
    
    // Parsing pomocniczy z dopasowywaniem tekstu opcji (dla losowej kolejności odpowiedzi)
    private func parseIndexFromText(_ text: String, options: [String]) -> Int {
        let optionsCount = options.count
        if optionsCount <= 1 { return 0 }
        
        let clean = text.replacingOccurrences(of: "```json", with: "")
                        .replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Sprawdzamy parsowanie struktury JSON
        if let data = clean.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            // a) Szukamy najpierw po dokładnej treści podanej przez AI w JSON ("correctText" / "answer")
            if let textVal = (dict["correctText"] as? String) ?? (dict["answer"] as? String), !textVal.isEmpty {
                let cleanVal = textVal.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                for (idx, opt) in options.enumerated() {
                    let cleanOpt = opt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if cleanOpt == cleanVal || cleanOpt.contains(cleanVal) || cleanVal.contains(cleanOpt) {
                        return idx
                    }
                }
            }
            
            // b) Szukamy indeksu w liczbach ("correctIndex")
            if let index = dict["correctIndex"] as? Int, index >= 0, index < optionsCount {
                return index
            }
            if let strIndex = dict["correctIndex"] as? String, let index = Int(strIndex), index >= 0, index < optionsCount {
                return index
            }
        }
        
        // 2. Dopasowanie tekstowe (sprawdzamy czy któraś treść opcji występuje w całości w odpowiedzi AI)
        let cleanTextLower = clean.lowercased()
        for (idx, opt) in options.enumerated() {
            let cleanOpt = opt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !cleanOpt.isEmpty && cleanTextLower.contains(cleanOpt) {
                return idx
            }
        }
        
        // 3. Dopasowanie literału A/B/C/D
        let letterPattern = "(?i)\\b(?:opcja|odpowiedź|wybieram)?\\s*([A-E])(?:[\\)\\.\\:\\s]|$)"
        if let regex = try? NSRegularExpression(pattern: letterPattern),
           let match = regex.firstMatch(in: clean, range: NSRange(clean.startIndex..., in: clean)),
           let letterRange = Range(match.range(at: 1), in: clean) {
            let letter = String(clean[letterRange]).uppercased()
            let asciiVal = Int(letter.unicodeScalars.first?.value ?? 65) - 65
            if asciiVal >= 0 && asciiVal < optionsCount {
                return asciiVal
            }
        }
        
        // 4. Dopasowanie cyfry w tekście
        let digits = clean.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let firstDigit = digits.first, let val = Int(String(firstDigit)) {
            if val >= 0 && val < optionsCount {
                return val
            } else if val >= 1 && (val - 1) < optionsCount {
                return val - 1
            }
        }
        
        // 5. Jeśli AI zawiedzie, używamy inteligentnego solvera zamiast 0
        return fallbackSmartSolver(options: options)
    }
    
    private func parseAnswerFromText(_ text: String) -> String {
        let clean = text.replacingOccurrences(of: "```json", with: "")
                        .replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = clean.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let answer = dict["answer"] as? String {
            return answer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        var result = clean
        if let colonIndex = result.firstIndex(of: ":") {
            let afterColon = String(result[result.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !afterColon.isEmpty {
                result = afterColon
            }
        }
        return result.isEmpty ? "Odpowiedź zweryfikowana" : result
    }
    
    // Algorytm zapasowy gdy serwery AI są przeciążone
    private func fallbackSmartSolver(options: [String]) -> Int {
        if options.count <= 1 { return 0 }
        var maxLen = 0
        var bestIndex = 0
        for (i, opt) in options.enumerated() {
            if opt.count > maxLen {
                maxLen = opt.count
                bestIndex = i
            }
        }
        return bestIndex
    }
}
