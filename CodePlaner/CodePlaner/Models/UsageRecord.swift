import Foundation

struct UsageRecord: Codable {
    let provider: String
    let model: String
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case provider, model
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case timestamp
    }
}
