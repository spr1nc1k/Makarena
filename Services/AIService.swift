import Foundation

/// Serwis odpowiedzialny za komunikację z bezpłatnym API Gemini (Google AI Studio) lub OpenRouter.
public class AIService {
    public static let shared = AIService()
    
    // Domyślny klucz API (może zostać zastąpiony własnym w ustawieniach aplikacji)
    public var apiKey: String = ""
    public var apiProvider: APIProvider = .gemini
    
    public enum APIProvider: String, CaseIterable, Identifiable {
        case gemini = "Google Gemini (Darmowy Tier)"
        case openRouter = "OpenRouter (Free Tier)"
        
        public var id: String { rawValue }
    }
    
    private init() {}
    
    /// Analizuje pytanie zamknięte i zwraca indeks prawidłowej odpowiedzi (0-indexed)
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
                    completion(.failure(NSError(domain: "AIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nie udało się sparsować indeksu odpowiedzi z AI"])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Analizuje pytanie otwarte i zwraca zwięzłą treść odpowiedzi
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
                    completion(.failure(NSError(domain: "AIService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Nie udało się sparsować odpowiedzi otwartej z AI"])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Wysyłanie żądania HTTP do API
    private func sendAIRequest(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !apiKey.isEmpty else {
            completion(.failure(NSError(domain: "AIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Brak klucza API. Wprowadź darmowy klucz Gemini w ustawieniach."])))
            return
        }
        
        switch apiProvider {
        case .gemini:
            sendGeminiRequest(prompt: prompt, completion: completion)
        case .openRouter:
            sendOpenRouterRequest(prompt: prompt, completion: completion)
        }
    }
    
    private func sendGeminiRequest(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "responseMimeType": "application/json"
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let content = firstCandidate["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    completion(.success(text))
                } else {
                    completion(.failure(NSError(domain: "AIService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Błędna odpowiedź z API Gemini"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func sendOpenRouterRequest(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "google/gemini-2.0-flash-lite-001",
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let text = message["content"] as? String {
                    completion(.success(text))
                } else {
                    completion(.failure(NSError(domain: "AIService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Błędna odpowiedź z OpenRouter"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Pomocnicze parsowanie JSON
    private func parseIndexFromJSON(_ jsonString: String) -> Int? {
        let clean = jsonString.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = clean.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let index = dict["correctIndex"] as? Int {
            return index
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
        return nil
    }
}
