import Foundation

/// Pula darmowych i płatnych dostawców API AI z automatycznym trybem Bezrejestracyjnym (Out-of-the-Box)
public class AIService {
    public static let shared = AIService()
    
    @Published public var apiKey: String = ""
    @Published public var apiProvider: APIProvider = .autoFreePool
    
    public enum APIProvider: String, CaseIterable, Identifiable {
        case autoFreePool = "🤖 Bezrejestracyjna Pula (Brak Klucza)"
        case pollinations = "Pollinations AI (Brak Klucza)"
        case llm7 = "LLM7.io (Brak Klucza)"
        case ovh = "OVHcloud AI (Brak Klucza)"
        case gemini = "Google Gemini 2.0 / 2.5 Flash"
        case groq = "GroqCloud (Llama 3.3 70B)"
        case cerebras = "Cerebras (Llama 3.3 70B)"
        case mistral = "Mistral AI (Mistral Small)"
        case sambanova = "SambaNova Cloud (Llama 3.3)"
        case openrouter = "OpenRouter (:free models)"
        case githubModels = "GitHub Models (GPT-4o / Llama)"
        case nvidia = "NVIDIA NIM"
        
        public var id: String { rawValue }
        
        public var baseURL: String {
            switch self {
            case .autoFreePool, .pollinations:
                return "https://text.pollinations.ai/openai"
            case .llm7:
                return "https://api.llm7.io/v1"
            case .ovh:
                return "https://oai.endpoints.kepler.ai.cloud.ovh.net/v1"
            case .gemini:
                return "https://generativelanguage.googleapis.com/v1beta/openai"
            case .groq:
                return "https://api.groq.com/openai/v1"
            case .cerebras:
                return "https://api.cerebras.ai/v1"
            case .mistral:
                return "https://api.mistral.ai/v1"
            case .sambanova:
                return "https://api.sambanova.ai/v1"
            case .openrouter:
                return "https://openrouter.ai/api/v1"
            case .githubModels:
                return "https://models.inference.ai.azure.com"
            case .nvidia:
                return "https://integrate.api.nvidia.com/v1"
            }
        }
        
        public var defaultModel: String {
            switch self {
            case .autoFreePool, .pollinations:
                return "openai"
            case .llm7:
                return "llama-3.3-70b"
            case .ovh:
                return "mistral-small"
            case .gemini:
                return "gemini-2.0-flash"
            case .groq:
                return "llama-3.3-70b-versatile"
            case .cerebras:
                return "llama3.3-70b"
            case .mistral:
                return "mistral-small-latest"
            case .sambanova:
                return "Meta-Llama-3.3-70B-Instruct"
            case .openrouter:
                return "google/gemini-2.0-flash-lite-001"
            case .githubModels:
                return "gpt-4o"
            case .nvidia:
                return "meta/llama-3.3-70b-instruct"
            }
        }
    }
    
    private init() {}
    
    /// Rozwiązywanie pytania zamkniętego
    public func solveClosedQuestion(question: String, options: [String], completion: @escaping (Result<Int, Error>) -> Void) {
        let optionsFormatted = options.enumerated().map { "[\($0.offset)] \($0.element)" }.joined(separator: "\n")
        
        let prompt = """
        Jesteś ekspertem rozwiązującym testy. Przeanalizuj poniższe pytanie i wyznacz dokładnie JEDNĄ prawidłową odpowiedź.
        
        Pytanie:
        \(question)
        
        Opcje:
        \(optionsFormatted)
        
        Zwróć ODPOWIEDŹ WYŁĄCZNIE W FORMATCIE JSON (bez bloku markdown, bez tekstu pobocznego):
        {"correctIndex": 0}
        """
        
        sendAIRequest(prompt: prompt) { result in
            switch result {
            case .success(let jsonString):
                if let index = self.parseIndexFromJSON(jsonString) {
                    completion(.success(index))
                } else {
                    completion(.failure(NSError(domain: "AIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nie udało się sparsować indeksu z JSON: \(jsonString)"])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Rozwiązywanie pytania otwartego
    public func solveOpenQuestion(question: String, completion: @escaping (Result<String, Error>) -> Void) {
        let prompt = """
        Jesteś ekspertem rozwiązującym testy. Odpowiedz zwięźle, precyzyjnie i poprawnie na poniższe pytanie otwarte.
        
        Pytanie:
        \(question)
        
        Zwróć ODPOWIEDŹ WYŁĄCZNIE W FORMATCIE JSON (bez bloku markdown, bez dodatkowego tekstu):
        {"answer": "Treść odpowiedzi"}
        """
        
        sendAIRequest(prompt: prompt) { result in
            switch result {
            case .success(let jsonString):
                if let answer = self.parseAnswerFromJSON(jsonString) {
                    completion(.success(answer))
                } else {
                    completion(.failure(NSError(domain: "AIService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Nie udało się sparsować odpowiedzi z JSON"])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Główny silnik wysyłania zapytania z automatycznym failoverem
    private func sendAIRequest(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        if apiProvider == .autoFreePool {
            // Próbujemy darmowych serwerów po kolei: Pollinations -> LLM7 -> OVH
            tryFreeProviderPool(prompt: prompt, providers: [.pollinations, .llm7, .ovh], completion: completion)
        } else {
            sendOpenAICompatibleRequest(provider: apiProvider, key: apiKey, prompt: prompt, completion: completion)
        }
    }
    
    private func tryFreeProviderPool(prompt: String, providers: [APIProvider], completion: @escaping (Result<String, Error>) -> Void) {
        guard let first = providers.first else {
            completion(.failure(NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Brak dostępnych darmowych serwerów w puli."])))
            return
        }
        
        let remaining = Array(providers.dropFirst())
        sendOpenAICompatibleRequest(provider: first, key: "", prompt: prompt) { result in
            switch result {
            case .success(let text):
                completion(.success(text))
            case .failure(_):
                // Próba z kolejnym darmowym serwerem
                self.tryFreeProviderPool(prompt: prompt, providers: remaining, completion: completion)
            }
        }
    }
    
    private func sendOpenAICompatibleRequest(provider: APIProvider, key: String, prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        let endpoint = "\(provider.baseURL)/chat/completions"
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "AIService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Nieprawidłowy URL API"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "model": provider.defaultModel,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.1
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "AIService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Brak danych z serwera"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let text = message["content"] as? String {
                    completion(.success(text))
                } else if let rawString = String(data: data, encoding: .utf8), !rawString.isEmpty {
                    completion(.success(rawString))
                } else {
                    completion(.failure(NSError(domain: "AIService", code: 422, userInfo: [NSLocalizedDescriptionKey: "Nieprawidłowa odpowiedź JSON"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func parseIndexFromJSON(_ jsonString: String) -> Int? {
        let clean = jsonString.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = clean.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let index = dict["correctIndex"] as? Int {
            return index
        }
        // Fallback: szukamy cyfry w tekście
        let digits = clean.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let firstDigit = digits.first, let val = Int(String(firstDigit)) {
            return val
        }
        return nil
    }
    
    private func parseAnswerFromJSON(_ jsonString: String) -> String? {
        let clean = jsonString.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = clean.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let answer = dict["answer"] as? String {
            return answer
        }
        return clean.isEmpty ? nil : clean
    }
}
