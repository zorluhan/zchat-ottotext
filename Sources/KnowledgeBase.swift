import Foundation

enum KnowledgeBase {
    static let combinedBase64 = ""
    static var combined: String {
        guard let data = Data(base64Encoded: combinedBase64) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
