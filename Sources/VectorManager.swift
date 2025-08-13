import Foundation
import GoogleGenerativeAI

@MainActor
class VectorManager {
    static let shared = VectorManager()
    
    private var knowledgeEmbeddings: [VectorEmbedding] = []
    private let embeddingsModel = GenerativeModel(name: "models/text-embedding-004", apiKey: ChatModel.apiKey)
    private let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    private var embeddingsFileURL: URL {
        return documentsURL.appendingPathComponent("ottoman_embeddings.json")
    }

    private init() {
        Task {
            await loadOrGenerateEmbeddings()
        }
    }
    
    func findRelevantContext(for query: String, maxResults: Int = 3) async -> String {
        guard !knowledgeEmbeddings.isEmpty else {
            print("Knowledge base is empty or not yet loaded.")
            return ""
        }
        
        do {
            let queryEmbeddingResult = try await embeddingsModel.embedContent(query)
            guard let queryVector = queryEmbeddingResult.embedding.values else {
                print("Failed to create embedding for query.")
                return ""
            }
            
            let similarities = knowledgeEmbeddings.map { embedding in
                (text: embedding.text, similarity: cosineSimilarity(a: queryVector, b: embedding.vector))
            }
            
            let sortedResults = similarities.sorted { $0.similarity > $1.similarity }
            let topResults = sortedResults.prefix(maxResults).map { $0.text }
            
            print("Found relevant chunks: \(topResults)")
            return topResults.joined(separator: "\n\n---\n\n")
            
        } catch {
            print("Error finding relevant context: \(error)")
            return ""
        }
    }

    private func loadOrGenerateEmbeddings() async {
        if FileManager.default.fileExists(atPath: embeddingsFileURL.path) {
            print("Loading existing embeddings from file...")
            do {
                let data = try Data(contentsOf: embeddingsFileURL)
                knowledgeEmbeddings = try JSONDecoder().decode([VectorEmbedding].self, from: data)
                print("Successfully loaded \(knowledgeEmbeddings.count) embeddings.")
            } catch {
                print("Error loading embeddings, will regenerate: \(error)")
                await generateAndSaveEmbeddings()
            }
        } else {
            print("No existing embeddings found. Generating new ones...")
            await generateAndSaveEmbeddings()
        }
    }
    
    private func generateAndSaveEmbeddings() async {
        guard let knowledgeURL = Bundle.main.url(forResource: "ottoman_knowledge", withExtension: "txt") else {
            print("Could not find ottoman_knowledge.txt in bundle.")
            return
        }
        
        do {
            let knowledgeText = try String(contentsOf: knowledgeURL)
            let chunks = chunkText(knowledgeText)
            print("Generating embeddings for \(chunks.count) text chunks...")
            
            var generatedEmbeddings: [VectorEmbedding] = []
            // Process chunks in batches to stay within API limits
            for chunkBatch in chunks.chunked(into: 50) {
                let content = chunkBatch.map { ModelContent.fromString($0) }
                let embeddingResult = try await embeddingsModel.batchEmbedContents(content)
                
                for (index, chunk) in chunkBatch.enumerated() {
                    if let vector = embeddingResult.embeddings[index].values {
                       generatedEmbeddings.append(VectorEmbedding(text: chunk, vector: vector))
                    }
                }
                print("Processed a batch of \(chunkBatch.count) chunks...")
            }

            self.knowledgeEmbeddings = generatedEmbeddings
            
            let data = try JSONEncoder().encode(knowledgeEmbeddings)
            try data.write(to: embeddingsFileURL)
            print("Successfully generated and saved \(knowledgeEmbeddings.count) embeddings.")
            
        } catch {
            print("Error generating embeddings: \(error)")
        }
    }
    
    private func chunkText(_ text: String, by paragraphs: Bool = true, chunkSize: Int = 500, overlap: Int = 50) -> [String] {
        let separators = CharacterSet(charactersIn: "\n\r")
        let paragraphs = text.components(separatedBy: separators).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        var chunks: [String] = []
        var currentChunk = ""
        
        for paragraph in paragraphs {
            if currentChunk.count + paragraph.count > chunkSize {
                chunks.append(currentChunk)
                currentChunk = String(currentChunk.suffix(overlap))
            }
            currentChunk += (currentChunk.isEmpty ? "" : "\n") + paragraph
        }
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks
    }
    
    private func cosineSimilarity(a: [Float], b: [Float]) -> Float {
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA != 0 && magnitudeB != 0 else { return 0 }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
}

// Helper struct for storing and saving embeddings
struct VectorEmbedding: Codable {
    let text: String
    let vector: [Float]
}

// Helper to batch an array into smaller arrays
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
