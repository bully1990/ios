import Foundation

struct ShopTextSummary {
    let shopName: String?
    let serviceContent: String?

    var hasUsefulContent: Bool {
        shopName?.isEmpty == false || serviceContent?.isEmpty == false
    }
}

enum DeepSeekClient {
    private static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    private static let model = "deepseek-chat"

    static func summarize(fullText: String, phoneNumber: String) async throws -> ShopTextSummary? {
        let apiKey = configuredAPIKey()
        guard !apiKey.isEmpty else {
            return nil
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(makeRequestBody(fullText: fullText, phoneNumber: phoneNumber))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content.data(using: .utf8) else {
            return nil
        }

        let summary = try JSONDecoder().decode(SummaryResponse.self, from: content)
        let result = ShopTextSummary(
            shopName: cleaned(summary.name),
            serviceContent: cleaned(summary.services)
        )

        return result.hasUsefulContent ? result : nil
    }

    private static func configuredAPIKey() -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "DeepSeekAPIKey") as? String else {
            return ""
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("$(") ? "" : trimmed
    }

    private static func makeRequestBody(fullText: String, phoneNumber: String) -> ChatCompletionRequest {
        let prompt = """
        你是一个门头照片 OCR 文本整理助手。请只根据给定 OCR 文本提取信息，不要编造。
        输出严格 JSON，不要 Markdown，不要解释。
        JSON 字段：
        - name: 店铺/公司/门头名称，无法判断则为空字符串
        - services: 主要服务内容，用简短中文短语概括，多个服务用顿号分隔，无法判断则为空字符串

        电话号码：\(phoneNumber)
        OCR 文本：
        \(fullText)
        """

        return ChatCompletionRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: "你只输出可被 JSONDecoder 解析的 JSON 对象。"),
                ChatMessage(role: "user", content: prompt)
            ],
            temperature: 0.1,
            responseFormat: ResponseFormat(type: "json_object")
        )
    }

    private static func cleaned(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case responseFormat = "response_format"
    }
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ResponseFormat: Encodable {
    let type: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}

private struct SummaryResponse: Decodable {
    let name: String?
    let services: String?
}
