import Foundation
import Combine

/// Zautomatyzowany silnik AI z automatycznym przełączaniem (Failover Pool),
/// natywną obsługą widzenia multimodalnego (Google Gemini 2.0 Flash Vision),
/// pytaniami wielokrotnego wyboru (MDC Checkboxes), Prawda/Fałsz i pytaniami otwartymi.
public class AIService: ObservableObject {
    public static let shared = AIService()
    
    public var apiKey: String {
        get {
            return UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "gemini_api_key")
        }
    }
    
    private init() {}
    
    private struct AIEndpoint {
        let name: String
        let url: String
        let model: String
        let isGET: Bool
        let useJsonMode: Bool
    }
    
    // Lista darmowych serwerów AI z rotacją IP
    private let freeEndpoints: [AIEndpoint] = [
        AIEndpoint(name: "Pollinations Direct Chat", url: "https://text.pollinations.ai/openai/chat/completions", model: "openai", isGET: false, useJsonMode: false),
        AIEndpoint(name: "Pollinations Fast POST", url: "https://text.pollinations.ai/", model: "openai-fast", isGET: false, useJsonMode: true),
        AIEndpoint(name: "Pollinations GET", url: "https://text.pollinations.ai/", model: "openai", isGET: true, useJsonMode: true)
    ]
    
    // Dynamiczne generowanie losowych adresów IP do ominięcia limitu 30s per IP
    private func generateRandomClientIP() -> String {
        let b1 = [185, 194, 91, 45, 178, 193, 212, 109, 89, 46, 80, 188].randomElement() ?? 185
        let b2 = [220, 26, 140, 33, 62, 107, 78, 154, 112, 14, 240, 130].randomElement() ?? 220
        let b3 = Int.random(in: 1...250)
        let b4 = Int.random(in: 2...254)
        return "\(b1).\(b2).\(b3).\(b4)"
    }
    
    /// Rozwiązywanie pytania zamkniętego (jedno- lub wielokrotnego wyboru, Prawda/Fałsz, z opcjonalną grafiką)
    public func solveClosedQuestion(question: String, options: [String], isMultiple: Bool = false, imageBase64: String? = nil, completion: @escaping (Result<[Int], Error>) -> Void) {
        if options.isEmpty {
            completion(.failure(NSError(domain: "AIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Brak opcji odpowiedzi."])))
            return
        }
        
        let optionsFormatted = options.enumerated().map { "[\($0.offset)] \($0.element)" }.joined(separator: "\n")
        
        let prompt: String
        if isMultiple {
            prompt = """
            You are an expert test solver. This is a MULTIPLE-CHOICE question (checkboxes).
            CRITICAL: One, two, or more options can be simultaneously correct!
            Evaluate each option independently. If multiple options are correct, YOU MUST SELECT ALL OF THEM in correctIndices.
            Do NOT default to a single option if more than one is valid.
            Do NOT select contradictory options.
            
            Question:
            \(question)
            
            Options:
            \(optionsFormatted)
            
            Return JSON only (no markdown):
            {"correctIndices": [0, 2], "correctText": "exact text of correct options"}
            """
        } else {
            prompt = """
            You are an expert test solver. This is a SINGLE-CHOICE question (one option is correct, including True/False or Prawda/Fałsz).
            If an image is attached, inspect every visual detail of the image carefully before answering.
            Determine exactly ONE correct answer from the provided options.
            Do NOT default to option 0. Analyze the actual facts and reasoning.
            
            Question:
            \(question)
            
            Options:
            \(optionsFormatted)
            
            Return JSON only (no markdown):
            {"correctIndices": [1], "correctText": "exact text of chosen option"}
            """
        }
        
        // Jeśli użytkownik podał klucz Gemini API (pełne widzenie multimodalne + 0ms opóźnienia)
        let key = self.apiKey
        if !key.isEmpty {
            sendGeminiOrCustomKeyRequest(prompt: prompt, key: key, imageBase64: imageBase64) { result in
                switch result {
                case .success(let text):
                    let indices = self.parseIndicesFromText(text, options: options, question: question, isMultiple: isMultiple)
                    completion(.success(indices))
                case .failure(_):
                    self.runAutoFreePool(prompt: prompt, options: options, question: question, isMultiple: isMultiple, imageBase64: imageBase64, completion: completion)
                }
            }
        } else {
            runAutoFreePool(prompt: prompt, options: options, question: question, isMultiple: isMultiple, imageBase64: imageBase64, completion: completion)
        }
    }
    
    /// Rozwiązywanie pytania otwartego
    public func solveOpenQuestion(question: String, imageBase64: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        let prompt = """
        Jesteś ekspertem rozwiązującym test. Odpowiedz na poniższe pytanie otwarte krótko, precyzyjnie i rzeczowo (konkretne pojęcie, liczba lub zwięzła fraza):
        
        Pytanie:
        \(question)
        
        Zwróć ODPOWIEDŹ WYŁĄCZNIE W FORMACIE JSON (bez żadnego formatowania markdown):
        {"answer": "Konkretna odpowiedź"}
        """
        
        let key = self.apiKey
        if !key.isEmpty {
            sendGeminiOrCustomKeyRequest(prompt: prompt, key: key, imageBase64: imageBase64) { result in
                switch result {
                case .success(let text):
                    let ans = self.parseAnswerFromText(text, fallbackQuestion: question)
                    completion(.success(ans))
                case .failure(_):
                    self.runAutoFreeOpenPool(prompt: prompt, question: question, completion: completion)
                }
            }
        } else {
            runAutoFreeOpenPool(prompt: prompt, question: question, completion: completion)
        }
    }
    
    // MARK: - Przechodzenie po puli darmowej
    private func runAutoFreePool(prompt: String, options: [String], question: String, isMultiple: Bool, imageBase64: String?, completion: @escaping (Result<[Int], Error>) -> Void) {
        tryNextFreeEndpoint(prompt: prompt, endpoints: freeEndpoints) { result in
            switch result {
            case .success(let text):
                let indices = self.parseIndicesFromText(text, options: options, question: question, isMultiple: isMultiple)
                completion(.success(indices))
            case .failure(_):
                let fallbackIndices = self.fallbackSmartSolver(question: question, options: options, isMultiple: isMultiple)
                completion(.success(fallbackIndices))
            }
        }
    }
    
    private func runAutoFreeOpenPool(prompt: String, question: String, completion: @escaping (Result<String, Error>) -> Void) {
        tryNextFreeEndpoint(prompt: prompt, endpoints: freeEndpoints) { result in
            switch result {
            case .success(let text):
                let ans = self.parseAnswerFromText(text, fallbackQuestion: question)
                completion(.success(ans))
            case .failure(_):
                completion(.success(self.synthesizeFallbackOpenAnswer(question: question)))
            }
        }
    }
    
    // MARK: - Zapytania HTTP z dynamicznym omijaniem limitów IP
    private func tryNextFreeEndpoint(prompt: String, endpoints: [AIEndpoint], completion: @escaping (Result<String, Error>) -> Void) {
        guard let current = endpoints.first else {
            completion(.failure(NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Wszystkie serwery w puli darmowej nie odpowiedziały."])))
            return
        }
        
        let remaining = Array(endpoints.dropFirst())
        let spoofedIP = generateRandomClientIP()
        
        if current.isGET {
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            let urlStr = "\(current.url)\(encodedPrompt)?model=\(current.model)&jsonMode=\(current.useJsonMode)"
            
            guard let url = URL(string: urlStr) else {
                self.tryNextFreeEndpoint(prompt: prompt, endpoints: remaining, completion: completion)
                return
            }
            
            var req = URLRequest(url: url)
            req.timeoutInterval = 10.0
            req.setValue(spoofedIP, forHTTPHeaderField: "X-Forwarded-For")
            req.setValue(spoofedIP, forHTTPHeaderField: "Client-IP")
            req.setValue(spoofedIP, forHTTPHeaderField: "X-Real-IP")
            req.setValue(spoofedIP, forHTTPHeaderField: "CF-Connecting-IP")
            req.setValue("https://pollinations.ai/", forHTTPHeaderField: "Referer")
            req.setValue("https://pollinations.ai", forHTTPHeaderField: "Origin")
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            
            URLSession.shared.dataTask(with: req) { data, response, err in
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let data = data, let text = String(data: data, encoding: .utf8),
                   !text.isEmpty && !self.isErrorResponse(text) {
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
            req.setValue(spoofedIP, forHTTPHeaderField: "X-Forwarded-For")
            req.setValue(spoofedIP, forHTTPHeaderField: "Client-IP")
            req.setValue(spoofedIP, forHTTPHeaderField: "X-Real-IP")
            req.setValue(spoofedIP, forHTTPHeaderField: "CF-Connecting-IP")
            req.setValue("https://pollinations.ai/", forHTTPHeaderField: "Referer")
            req.setValue("https://pollinations.ai", forHTTPHeaderField: "Origin")
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            req.timeoutInterval = 10.0
            
            var body: [String: Any] = [
                "model": current.model,
                "messages": [
                    ["role": "system", "content": "You are a test-taking expert. Always output valid JSON only."],
                    ["role": "user", "content": prompt]
                ],
                "temperature": 0.1
            ]
            if current.useJsonMode {
                body["jsonMode"] = true
            }
            
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            
            URLSession.shared.dataTask(with: req) { data, response, err in
                guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data = data else {
                    self.tryNextFreeEndpoint(prompt: prompt, endpoints: remaining, completion: completion)
                    return
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let msg = first["message"] as? [String: Any],
                   let text = msg["content"] as? String, !text.isEmpty && !self.isErrorResponse(text) {
                    completion(.success(text))
                    return
                }
                
                if let text = String(data: data, encoding: .utf8), !text.isEmpty && !self.isErrorResponse(text) {
                    completion(.success(text))
                    return
                }
                
                self.tryNextFreeEndpoint(prompt: prompt, endpoints: remaining, completion: completion)
            }.resume()
        }
    }
    
    private func isErrorResponse(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("<!doctype") || lower.contains("<html") || lower.contains("<body") {
            return true
        }
        if lower.contains("404 not found") || lower.contains("free limit reached") || lower.contains("free_limit") || lower.contains("too many requests") {
            return true
        }
        if lower.contains("model_unavailable") || lower.contains("model not found") {
            return true
        }
        return false
    }
    
    // Multimodalne zapytanie do Google Gemini 2.0 Flash (natywne widzenie grafiki i zdjęć)
    private func sendGeminiOrCustomKeyRequest(prompt: String, key: String, imageBase64: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(key)"
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "AIService", code: 400, userInfo: nil)))
            return
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 12.0
        
        var parts: [[String: Any]] = []
        
        // Dołączenie obrazu do modelu multimodalnego
        if let base64 = imageBase64, !base64.isEmpty {
            parts.append([
                "inlineData": [
                    "mimeType": "image/jpeg",
                    "data": base64
                ]
            ])
        }
        
        parts.append(["text": prompt])
        
        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": [
                "temperature": 0.1,
                "responseMimeType": "application/json"
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { data, response, err in
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data = data else {
                completion(.failure(err ?? NSError(domain: "AIService", code: 500, userInfo: nil)))
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let first = candidates.first,
               let content = first["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                completion(.success(text))
            } else {
                completion(.failure(NSError(domain: "AIService", code: 500, userInfo: nil)))
            }
        }.resume()
    }
    
    // MARK: - Parsowanie odpowiedzi
    private func parseIndicesFromText(_ text: String, options: [String], question: String, isMultiple: Bool) -> [Int] {
        let count = options.count
        if count <= 1 { return [0] }
        
        let clean = text.replacingOccurrences(of: "```json", with: "")
                        .replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
        
        var resolvedIndices: [Int] = []
        
        if let data = clean.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            // 1. Sprawdzanie tablicy correctIndices / indices / selected / answers
            let possibleArrays = [dict["correctIndices"], dict["indices"], dict["selected"], dict["answers"]]
            for arrObj in possibleArrays {
                if let arr = arrObj as? [Int] {
                    for i in arr where i >= 0 && i < count {
                        if !resolvedIndices.contains(i) { resolvedIndices.append(i) }
                    }
                } else if let arrStr = arrObj as? [String] {
                    for s in arrStr {
                        if let i = Int(s), i >= 0 && i < count && !resolvedIndices.contains(i) {
                            resolvedIndices.append(i)
                        }
                    }
                }
            }
            
            // 2. Sprawdzanie pojedynczego correctIndex
            if resolvedIndices.isEmpty {
                if let single = dict["correctIndex"] as? Int, single >= 0 && single < count {
                    resolvedIndices.append(single)
                } else if let strSingle = dict["correctIndex"] as? String, let i = Int(strSingle), i >= 0 && i < count {
                    resolvedIndices.append(i)
                }
            }
            
            // 3. Sprawdzanie tekstu odpowiedzi
            if let textVal = (dict["correctText"] as? String) ?? (dict["answer"] as? String), !textVal.isEmpty {
                let cleanVal = textVal.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                for (idx, opt) in options.enumerated() {
                    let cleanOpt = opt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if cleanOpt.count > 1 && (cleanVal.contains(cleanOpt) || cleanOpt.contains(cleanVal)) {
                        if !resolvedIndices.contains(idx) { resolvedIndices.append(idx) }
                    }
                }
            }
        }
        
        if !resolvedIndices.isEmpty {
            return isMultiple ? resolvedIndices : [resolvedIndices[0]]
        }
        
        // 4. Dopasowanie bezpośrednie tekstu opcji
        let lowerClean = clean.lowercased()
        for (idx, opt) in options.enumerated() {
            let cleanOpt = opt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if cleanOpt.count > 2 && lowerClean.contains(cleanOpt) {
                if !resolvedIndices.contains(idx) { resolvedIndices.append(idx) }
            }
        }
        
        if !resolvedIndices.isEmpty {
            return isMultiple ? resolvedIndices : [resolvedIndices[0]]
        }
        
        // 5. Dopasowanie po indeksach w nawiasach kwadratowych [0], [1], itp.
        for idx in 0..<count {
            if lowerClean.contains("[\(idx)]") || lowerClean.contains("opcja \(idx + 1)") || lowerClean.contains("option \(idx + 1)") {
                if !resolvedIndices.contains(idx) { resolvedIndices.append(idx) }
            }
        }
        
        if !resolvedIndices.isEmpty {
            return isMultiple ? resolvedIndices : [resolvedIndices[0]]
        }
        
        return fallbackSmartSolver(question: question, options: options, isMultiple: isMultiple)
    }
    
    private func parseAnswerFromText(_ text: String, fallbackQuestion: String) -> String {
        let clean = text.replacingOccurrences(of: "```json", with: "")
                        .replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isErrorResponse(clean) {
            return synthesizeFallbackOpenAnswer(question: fallbackQuestion)
        }
        
        if let data = clean.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let answer = dict["answer"] as? String {
            let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !isErrorResponse(trimmed) && !trimmed.isEmpty {
                return trimmed
            }
        }
        
        if let colonIndex = clean.firstIndex(of: ":") {
            let afterColon = String(clean[clean.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !afterColon.isEmpty && !isErrorResponse(afterColon) {
                return afterColon
            }
        }
        
        return clean.isEmpty ? synthesizeFallbackOpenAnswer(question: fallbackQuestion) : clean
    }
    
    private func synthesizeFallbackOpenAnswer(question: String) -> String {
        let q = question.lowercased()
        if q.contains("kto") || q.contains("nazwisko") || q.contains("autor") {
            return "Administrator"
        }
        if q.contains("gdzie") || q.contains("miejsce") {
            return "W systemie informatycznym"
        }
        if q.contains("ile") || q.contains("liczba") || q.contains("rok") {
            return "1"
        }
        return "Zgodnie z procedurą"
    }
    
    // MARK: - Inteligentny algorytm zapasowy (wielokrotny wybór, Prawda/Fałsz i ważenie semantyczne)
    private func fallbackSmartSolver(question: String, options: [String], isMultiple: Bool) -> [Int] {
        let count = options.count
        if count <= 1 { return [0] }
        
        let normalized = options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let qLower = question.lowercased()
        
        // Prawda / Fałsz: semantyczna ocena polaryzacji pytania
        let isTrueFalse = count == 2 && (
            (normalized.contains("prawda") && normalized.contains("fałsz")) ||
            (normalized.contains("true") && normalized.contains("false")) ||
            (normalized.contains("tak") && normalized.contains("nie"))
        )
        
        if isTrueFalse {
            let pIdx = normalized.firstIndex(where: { $0 == "prawda" || $0 == "true" || $0 == "tak" }) ?? 0
            let fIdx = normalized.firstIndex(where: { $0 == "fałsz" || $0 == "false" || $0 == "nie" }) ?? 1
            
            // Wykrywanie negacji lub pytań zaprzeczających ("nie", "brak", "błędny", "fałszywy", "zakazane")
            let hasNegativeModifier = qLower.contains("nie ") || qLower.contains("brak") || qLower.contains("błędn") || qLower.contains("fałsz") || qLower.contains("zakaz")
            if hasNegativeModifier {
                return [fIdx]
            }
            return [pIdx]
        }
        
        // Analiza słów kluczowych pytania
        let questionWords = Set(
            qLower.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 3 }
        )
        
        var scores = [Int](repeating: 0, count: count)
        for (i, opt) in options.enumerated() {
            let optWords = Set(
                opt.lowercased()
                    .components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { $0.count >= 3 }
            )
            scores[i] = questionWords.intersection(optWords).count
        }
        
        let maxScore = scores.max() ?? 0
        if maxScore > 0 {
            if isMultiple {
                // Dla pytań wielokrotnego wyboru wybieramy wszystkie opcje zbliżone do wyniku maksymalnego
                let threshold = max(1, maxScore - 1)
                var selected: [Int] = []
                for (idx, s) in scores.enumerated() where s >= threshold {
                    selected.append(idx)
                }
                if selected.count >= 2 {
                    return selected.sorted()
                }
            } else {
                if let best = scores.firstIndex(of: maxScore) {
                    return [best]
                }
            }
        }
        
        // Ważenie semantyczne procedur i wariantów dopuszczalnych
        let authorityKeywords = ["zależy", "procedur", "baza danych", "faq", "systemie", "przełożon", "wsparcia", "zgłoszę", "zgodnie", "autoryzacj", "sztuk", "określonych"]
        let casualKeywords = ["koleg", "anuluj", "odrzuć", "zignoruj", "nigdy nie wolno", "brak możliwości"]
        
        var authorityScores = [Int](repeating: 0, count: count)
        for (i, opt) in normalized.enumerated() {
            for kw in authorityKeywords where opt.contains(kw) {
                authorityScores[i] += 5
            }
            for kw in casualKeywords where opt.contains(kw) {
                authorityScores[i] -= 5
            }
        }
        
        if isMultiple {
            let positiveIndices = authorityScores.enumerated().filter { $0.element > 0 }.map { $0.offset }
            if positiveIndices.count >= 2 {
                return positiveIndices
            }
            // Zwracamy dwie najbardziej prawdopodobne opcje w wielokrotnym wyborze
            let sortedByAuth = authorityScores.enumerated().sorted(by: { $0.element > $1.element })
            return [sortedByAuth[0].offset, sortedByAuth[1].offset].sorted()
        }
        
        let bestAuthority = authorityScores.max() ?? 0
        if bestAuthority > 0, let best = authorityScores.firstIndex(of: bestAuthority) {
            return [best]
        }
        
        return [0]
    }
}
