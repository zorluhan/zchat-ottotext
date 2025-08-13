import Foundation
import SwiftUI

struct ChatMessage: Codable, Identifiable, Hashable {
    var id = UUID()
    let role: String
    let text: String
    let time = Date()
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
}

@MainActor
class ChatModel: ObservableObject {
    
    @Published var messages = [ChatMessage]()
    private let knowledgeBaseText: String
    private let apiKey = APIKey.key // Use the key from APIKey.swift

    init() {
        // Load the knowledge base from the compile-time constant
        self.knowledgeBaseText = KnowledgeBase.combined
        print("Knowledge base loaded from compiled source. Length: \(self.knowledgeBaseText.count) chars")
        
        // Load initial message
        messages.append(ChatMessage(role: "system", text: "Selam! Bana Osmanlıca çevirisini istediğin bir metin ver."))
    }

    func addUser(_ text: String) {
        messages.append(ChatMessage(role: "user", text: text))
    }
    
    private func addAssistant(_ text: String) {
        messages.append(ChatMessage(role: "model", text: text))
    }
    
    func convert(text: String) async {
        guard !apiKey.isEmpty else {
            addAssistant("API key missing. Please set it in APIKey.swift")
            return
        }

        let prompt = """
        \(knowledgeBaseText)

        INPUT:
        \(text)
        """
        
        print("--- PROMPT SENT TO GEMINI ---\n\(prompt)\n-----------------------------")
        
        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?key=\(apiKey)"
        guard let endpoint = URL(string: urlStr) else {
            addAssistant("Error: Invalid API endpoint.")
            return
        }
        
        var attempt = 0
        let maxAttempts = 3
        
        while attempt < maxAttempts {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let payload: [String: Any] = [
                "contents": [["role": "user", "parts": [["text": prompt]]]],
                "generationConfig": [
                    "temperature": 0.0,
                    "maxOutputTokens": 2048,
                    "responseMimeType": "text/plain"
                ]
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        if let responseText = parseText(from: data) {
                            addAssistant(responseText)
                        } else {
                            addAssistant("The system returned an unreadable response. Please try again.")
                        }
                        return
                    }
                    
                    // Handle 429 rate limit with backoff
                    if httpResponse.statusCode == 429 {
                        let retryAfterHeader = httpResponse.value(forHTTPHeaderField: "Retry-After")
                        let retrySeconds: Double
                        if let header = retryAfterHeader, let headerVal = Double(header) { retrySeconds = headerVal } else { retrySeconds = pow(2.0, Double(attempt)) }
                        print("429 received. Attempt \(attempt + 1)/\(maxAttempts). Retrying in \(retrySeconds)s…")
                        try? await Task.sleep(nanoseconds: UInt64(retrySeconds * 1_000_000_000))
                        attempt += 1
                        continue
                    }
                    
                    // Log response body for debugging other errors
                    let body = String(data: data, encoding: .utf8) ?? "<no-body>"
                    print("API Error: status=\(httpResponse.statusCode) body=\(body)")
                } else {
                    // Fallback for non-HTTP responses
                    print("API Error: Received a non-HTTP response.")
                }
                
                // Non-HTTPURLResponse fallback
                addAssistant("The system is not available right now. Please try again later.")
                return
            } catch {
                print("API Request Error (attempt \(attempt + 1)): \(error)")
                attempt += 1
                // brief backoff on transport errors
                try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
            }
        }
        
        addAssistant("The system is experiencing heavy load. Please try again in a moment.")
    }
    
    private func parseText(from data: Data) -> String? {
        // Parse once into a root object
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        // Log block reason if present
        if let feedback = root["promptFeedback"] as? [String: Any],
           let reason = feedback["blockReason"] as? String {
            print("Content blocked by API. Reason: \(reason)")
        }
        
        // Extract text from the first candidate
        if let candidates = root["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
}
