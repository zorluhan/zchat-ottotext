import Foundation
import SwiftUI
import GoogleGenerativeAI

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
    
    // This is not secure for a production app.
    // See https://ai.google.dev/gemini-api/docs/api-key-setup
    static let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""

    @Published var messages = [ChatMessage]()
    
    private var generativeModel: GenerativeModel
    private let vectorManager = VectorManager.shared // Initialize the manager

    init() {
        guard !ChatModel.apiKey.isEmpty else {
            fatalError("Please provide an API Key in ChatModel.swift by setting the GEMINI_API_KEY environment variable.")
        }
        
        let config = GenerationConfig(
            responseMIMEType: "text/plain",
            temperature: 0,
            maxOutputTokens: 2048
        )
        
        self.generativeModel = GenerativeModel(
            name: "gemini-1.5-pro-latest",
            apiKey: ChatModel.apiKey,
            generationConfig: config
        )
        
        // Load initial message
        messages.append(ChatMessage(role: "system", text: "Selam! Bana Osmanlıca çevirisini istediğin bir metin ver."))
    }

    func addUser(_ text: String) {
        messages.append(ChatMessage(role: "user", text: text))
    }
    
    func addAssistant(_ text: String) {
        messages.append(ChatMessage(role: "model", text: text))
    }
    
    func convert(text: String) async {
        let relevantContext = await vectorManager.findRelevantContext(for: text)
        
        let prompt: String
        if !relevantContext.isEmpty {
            prompt = """
            REFERENCE CONTEXT:
            ---
            \(relevantContext)
            ---
            Based *only* on the reference context, if it is relevant, and your own knowledge, convert the following Turkish text to Ottoman script.
            
            TEXT TO CONVERT:
            \(text)
            """
        } else {
            prompt = """
            Convert the following Turkish text to Ottoman script.
            
            TEXT TO CONVERT:
            \(text)
            """
        }

        do {
            let response = try await generativeModel.generateContent(prompt)
            
            if let responseText = response.text {
                addAssistant(responseText)
            } else {
                addAssistant("The system returned an empty response. Please try again.")
            }
        } catch {
            print("Gemini error:", error)
            addAssistant("The system is not available right now. Please try again later.")
        }
    }
}
