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
    
    private let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""

    init() {
        // Load the knowledge base from ottoman_knowledge.txt
        if let url = Bundle.main.url(forResource: "ottoman_knowledge", withExtension: "txt"),
           let text = try? String(contentsOf: url) {
            self.knowledgeBaseText = text
            print("Successfully loaded knowledge base.")
        } else {
            self.knowledgeBaseText = ""
            print("Warning: Could not load ottoman_knowledge.txt. Knowledge base will be empty.")
        }
        
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
            addAssistant("API key missing. Set GEMINI_API_KEY in the scheme.")
            return
        }

        let prompt = """
        REFERENCE TEXT:
        ---
        \(knowledgeBaseText)
        ---
        Based on the reference text provided above, convert the following Turkish text to Ottoman script. Return only the final Ottoman script.

        TEXT TO CONVERT:
        \(text)
        """
        
        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?key=\(apiKey)"
        guard let endpoint = URL(string: urlStr) else {
            addAssistant("Error: Invalid API endpoint.")
            return
        }
        
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
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("API Error: Invalid response - \(response)")
                addAssistant("The system is not available right now. Please try again later.")
                return
            }
            
            if let responseText = parseText(from: data) {
                addAssistant(responseText)
            } else {
                addAssistant("The system returned an unreadable response. Please try again.")
            }
            
        } catch {
            print("API Request Error: \(error)")
            addAssistant("An error occurred while communicating with the system.")
        }
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
