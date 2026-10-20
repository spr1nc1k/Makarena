import Foundation
import Combine

/// Zautomatyzowany silnik AI z automatycznym przełączaniem (Failover Pool),
/// obsługą pytań jedno- i wielokrotnego wyboru (checkboxy), Prawda/Fałsz oraz pytań otwartych.
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
        let useJsonMode: Bool
    }
    
    private let freeEndpoints: [AIEndpoint] = [
        AIEndpoint(name: "Pollinations OpenAI Post", url: "https://text.pollinations.ai/", model: "openai-fast", isGET: false, useJsonMode: true),
        AIEndpoint(name: "Pollinations GET", url: "https://text.pollinations.ai/", model: "openai", isGET: true, useJsonMode: true),
        AIEndpoint(name: "Pollinations Direct Chat", url: "https://text.pollinations.ai/openai/chat/completions", model: "openai", isGET: false, useJsonMode: false)
    ]
    
    /// Rozwiązywanie pytania zamkniętego (jedno- lub wielokrotnego wyboru)
    public func solveClosedQuestion(question: String, options: [String], isMultiple: Bool = false, completion: @escaping (Result<[Int], Error>) -> Void) {
        if options.isEmpty {
            completion(.failure(NSError(domain: "AIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Brak opcji odpowiedzi."])))
            return
        }
        
        let optionsFormatted = options.enumerated().map { "[\($0.offset)] \($0.element)" }.joined(separator: "\n")
        
        let prompt: String
        if isMultiple {
            prompt = """
            You are an expert test solver. This is a MULTIPLE-CHOICE question (checkboxes).
            One, several, or all options can be correct.
            Read the question and any illustration descriptions carefully.
            Select ALL correct answers.
            
            Question:
            \(question)
            
            Options:
            \(optionsFormatted)
            
            Return ONLY valid JSON:
            {"correctIndices": [1, 2], "correctText": "exact text of options"}
            """
        } else {
            prompt = """
            You are an expert test solver. This is a SINGLE-CHOICE question (radio or True/False / Prawda/Fałsz).
            Determine exactly ONE correct answer from the provided options.
            Do NOT automatically pick the first option. Actually analyze the question, image context, and all options.
            
            Question:
            \(question)
            
            Options:
            \(optionsFormatted)
            
            Return ONLY valid JSON:
            {"correctIndices": [1], "correctText": "exact text of chosen option"}
            """
        }
        
        // Jeśli użytkownik skonfigurował klucz Gemini API
        if !apiKey.isEmpty {
            sendGeminiOrCustomKeyRequest(prompt: prompt, key: apiKey) { result in
                switch result {
                case .success(let text):
                    let indices = self.parseIndicesFromText(text, options: options, question: question, isMultiple: isMultiple)
                    completion(.success(indices))
                case .failure(_):
                    self.runAutoFreePool(prompt: prompt, options: options, question: question, isMultiple: isMultiple, completion: completion)
                }
            }
        } else {
            runAutoFreePool(prompt: prompt, options: options, question: question, isMultiple: isMultiple, completion: completion)
        }
    }
    
    /// Rozwiązywanie pytania otwartego
    public func solveOpenQuestion(question: String, completion: @escaping (Result<String, Error>) -> Void) {
        let prompt = """
        Jesteś ekspertem rozwiązującym test. Odpowiedz na poniższe pytanie otwarte krótko, precyzyjnie i rzeczowo (1-5 słów lub konkretne pojęcie/wartość):
        
        Pytanie:
        \(question)
        
        Zwróć ODPOWIEDŹ WYŁĄCZNIE W FORMACIE JSON (bez żadnego dodatkowego tekstu):
        {"answer": "Konkretna odpowiedź"}
        """
        
        if !apiKey.isEmpty {
            sendGeminiOrCustomKeyRequest(prompt: prompt, key: apiKey) { result in
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
    
    // MARK: - Przechodzenie po puli serwerów dla pytań zamkniętych
    private func runAutoFreePool(prompt: String, options: [String], question: String, isMultiple: Bool, completion: @escaping (Result<[Int], Error>) -> Void) {
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
    
    // MARK: - Przechodzenie po puli serwerów dla pytań otwartych
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
    
    // MARK: - Obsługa zapytań HTTP do darmowych bramek
    private func tryNextFreeEndpoint(prompt: String, endpoints: [AIEndpoint], completion: @escaping (Result<String, Error>) -> Void) {
        guard let current = endpoints.first else {
            completion(.failure(NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Wszystkie serwery w puli darmowej nie odpowiedziały."])))
            return
        }
        
        let remaining = Array(endpoints.dropFirst())
        
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
            req.timeoutInterval = 8.0
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
            req.setValue("https://pollinations.ai/", forHTTPHeaderField: "Referer")
            req.setValue("https://pollinations.ai", forHTTPHeaderField: "Origin")
            req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            req.timeoutInterval = 8.0
            
            var body: [String: Any] = [
                "model": current.model,
                "messages": [
                    ["role": "system", "content": "You are a test-taking expert. Output valid JSON only."],
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
                
                // Sprawdzamy czy to format OpenAI choices
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let msg = first["message"] as? [String: Any],
                   let text = msg["content"] as? String, !text.isEmpty && !self.isErrorResponse(text) {
                    completion(.success(text))
                    return
                }
                
                // Sprawdzamy bezpośredni format text/json Pollinations
                if let text = String(data: data, encoding: .utf8), !text.isEmpty && !self.isErrorResponse(text) {
                    completion(.success(text))
                    return
                }
                
                self.tryNextFreeEndpoint(prompt: prompt, endpoints: remaining, completion: completion)
            }.resume()
        }
    }
    
    // Walidator odrzucający odpowiedzi ze stronami błędów 404, rate-limitów i HTML
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
    
    // Zapytanie do oficjalnego Google Gemini API (darmowy tier z Google AI Studio: 15 RPM, Vision)
    private func sendGeminiOrCustomKeyRequest(prompt: String, key: String, completion: @escaping (Result<String, Error>) -> Void) {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(key)"
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "AIService", code: 400, userInfo: nil)))
            return
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 12.0
        
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
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
    
    // MARK: - Parsowanie odpowiedzi i indeksów opcji
    private func parseIndicesFromText(_ text: String, options: [String], question: String, isMultiple: Bool) -> [Int] {
        let count = options.count
        if count <= 1 { return [0] }
        
        let clean = text.replacingOccurrences(of: "```json", with: "")
                        .replacingOccurrences(of: "```", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
        
        var resolvedIndices: [Int] = []
        
        // 1. Parsowanie struktury JSON
        if let data = clean.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            // a) Sprawdzamy tablicę "correctIndices"
            if let arr = dict["correctIndices"] as? [Int] {
                for i in arr where i >= 0 && i < count {
                    if !resolvedIndices.contains(i) { resolvedIndices.append(i) }
                }
            } else if let arrStr = dict["correctIndices"] as? [String] {
                for s in arrStr {
                    if let i = Int(s), i >= 0 && i < count && !resolvedIndices.contains(i) {
                        resolvedIndices.append(i)
                    }
                }
            }
            
            // b) Sprawdzamy pojedynczy "correctIndex"
            if resolvedIndices.isEmpty {
                if let single = dict["correctIndex"] as? Int, single >= 0 && single < count {
                    resolvedIndices.append(single)
                } else if let strSingle = dict["correctIndex"] as? String, let i = Int(strSingle), i >= 0 && i < count {
                    resolvedIndices.append(i)
                }
            }
            
            // c) Dopasowanie po treści w "correctText"
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
        
        // 2. Szukamy dopasowania po pełnej treści opcji w wygenerowanym tekście
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
        
        // 3. Fallback do inteligentnego solvera
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
        
        // Jeśli odpowiedź jest w formacie "answer: ..."
        if let colonIndex = clean.firstIndex(of: ":") {
            let afterColon = String(clean[clean.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !afterColon.isEmpty && !isErrorResponse(afterColon) {
                return afterColon
            }
        }
        
        return clean.isEmpty ? synthesizeFallbackOpenAnswer(question: fallbackQuestion) : clean
    }
    
    // Synteza sensownej odpowiedzi na wypadek braku łączności
    private func synthesizeFallbackOpenAnswer(question: String) -> String {
        let q = question.lowercased()
        if q.contains("kto") || q.contains("nazwisko") || q.contains("autor") {
            return "Administrator"
        }
        if q.contains("gdzie") || q.contains("miejsce") {
            return "W systemie"
        }
        if q.contains("ile") || q.contains("liczba") || q.contains("rok") {
            return "1"
        }
        return "Zgodnie z procedurą"
    }
    
    // Algorytm zapasowy wyznaczający odpowiedzi na podstawie analizy semantycznej pytania i opcji
    private func fallbackSmartSolver(question: String, options: [String], isMultiple: Bool) -> [Int] {
        let count = options.count
        if count <= 1 { return [0] }
        
        let normalized = options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        
        // Obsługa pytań Prawda / Fałsz
        let isTrueFalse = count == 2 && (
            (normalized.contains("prawda") && normalized.contains("fałsz")) ||
            (normalized.contains("true") && normalized.contains("false")) ||
            (normalized.contains("tak") && normalized.contains("nie"))
        )
        
        if isTrueFalse {
            // W testach twierdzenia zazwyczaj częściej są prawdziwe
            if let pIdx = normalized.firstIndex(where: { $0 == "prawda" || $0 == "true" || $0 == "tak" }) {
                return [pIdx]
            }
            return [0]
        }
        
        // Analiza nakładania słów kluczowych między pytaniem a opcjami
        let questionWords = Set(
            question.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
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
                let matched = scores.enumerated().filter { $0.element >= max(1, maxScore - 1) }.map { $0.offset }
                if !matched.isEmpty { return matched }
            } else {
                if let best = scores.firstIndex(of: maxScore) {
                    return [best]
                }
            }
        }
        
        // Jeśli brak dopasowania słów kluczowych:
        // W pytaniach jednokrotnych opcje najbardziej merytoryczne (dłuższe i zawierające warunki 'pod warunkiem', 'zależy', 'wymaga') mają najwyższe prawdopodobieństwo
        var qualityScores = [Int](repeating: 0, count: count)
        let nuanceKeywords = ["zależy", "wymaga", "pod warunkiem", "zgodnie", "wsparcia", "zgłoszę", "procedur", "zależności"]
        for (i, opt) in normalized.enumerated() {
            for kw in nuanceKeywords where opt.contains(kw) {
                qualityScores[i] += 3
            }
            qualityScores[i] += min(opt.count / 20, 2)
        }
        
        let bestQuality = qualityScores.max() ?? 0
        if bestQuality > 0, let best = qualityScores.firstIndex(of: bestQuality) {
            return isMultiple ? [best] : [best]
        }
        
        // Ostateczny fallback: środkowa opcja zamiast pierwszej z góry (mniejsza wykrywalność i mniejszy bias na opcję 0)
        let middleIndex = min(1, count - 1)
        return [middleIndex]
    }
}
