import Foundation
import SwiftUI

struct ChatEntry: Identifiable {
    let id = UUID().uuidString
    let time = Date()
    let role: String
    let text: String

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: time)
    }
}

final class ChatModel: ObservableObject {
    @Published var messages: [ChatEntry] = []
    @Published var apiKey: String = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""

    var kbText: String {
        if let url = Bundle.main.url(forResource: "ottoman", withExtension: "txt"),
           let s = try? String(contentsOf: url, encoding: .utf8) {
            return String(s.prefix(80_000))
        }
        return ""
    }

    func addUser(_ text: String) { messages.append(.init(role: "user", text: text)) }
    func addAssistant(_ text: String) { messages.append(.init(role: "assistant", text: text)) }

    func convert(text: String) async {
        guard !apiKey.isEmpty else {
            addAssistant("API key missing. Set GEMINI_API_KEY in the scheme.")
            return
        }
        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent?key=\(apiKey)"
        guard let endpoint = URL(string: urlStr) else { return }
        func makeRequest(maxTokens: Int) -> URLRequest {
            var req = URLRequest(url: endpoint)
            req.httpMethod = "POST"
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            let system = "You are an expert Ottoman Turkish scribe. Convert modern Turkish (Latin) into Ottoman Arabic script. Return only the Ottoman-script text; no explanations."
            let ref = kbText.isEmpty ? "" : "\n\nReference about orthography:\n" + kbText
            let combined = system + ref + "\n\nText to convert:\n" + text
            let payload: [String: Any] = [
                "contents": [["role": "user", "parts": [["text": combined]]]],
                "generationConfig": [
                    "temperature": 0.0,
                    "maxOutputTokens": maxTokens,
                    "responseMimeType": "text/plain"
                ]
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            return req
        }
        do {
            var req = makeRequest(maxTokens: 2048)
            var (data, resp) = try await URLSession.shared.data(for: req)
            if (resp as? HTTPURLResponse)?.statusCode == 200, let t = parseText(data) {
                await MainActor.run { self.addAssistant(t) }
                return
            }
            req = makeRequest(maxTokens: 4096)
            (data, resp) = try await URLSession.shared.data(for: req)
            if (resp as? HTTPURLResponse)?.statusCode == 200, let t = parseText(data) {
                await MainActor.run { self.addAssistant(t) }
                return
            }
            let body = String(data: data, encoding: .utf8) ?? "<no-body>"
            print("Gemini non-200:", (resp as? HTTPURLResponse)?.statusCode ?? -1, body)
            await MainActor.run { self.addAssistant("The system is not available right now. Please try again later.") }
        } catch {
            print("Gemini error:", error)
            await MainActor.run { self.addAssistant("The system is not available right now. Please try again later.") }
        }
    }

    private func parseText(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let cands = json["candidates"] as? [[String: Any]],
           let content = cands.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let t = parts.first?["text"] as? String {
            return t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let finish = (json["candidates"] as? [[String: Any]])?.first?["finishReason"] as? String {
            print("finishReason:", finish)
        }
        print("no-text json:", json)
        return nil
    }
}
