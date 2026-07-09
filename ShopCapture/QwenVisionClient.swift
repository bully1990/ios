import Foundation

enum QwenVisionClient {
    private static let endpoint = URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions")!
    private static let model = "qwen3.5-omni-plus"

    enum QwenVisionError: LocalizedError {
        case missingAPIKey
        case invalidImage
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "未配置 DASHSCOPE_API_KEY"
            case .invalidImage:
                return "图片数据无效"
            case .emptyResponse:
                return "AI 未返回识别结果"
            }
        }
    }

    static func summarize(imageData: Data, phoneNumber: String = "") async throws -> ShopTextSummary? {
        let dataURL = "data:image/jpeg;base64,\(imageData.base64EncodedString())"
        return try await summarize(imageURL: dataURL, phoneNumber: phoneNumber)
    }

    static func summarize(imageURL: String, phoneNumber: String) async throws -> ShopTextSummary? {
        let apiKey = configuredAPIKey()
        guard !apiKey.isEmpty, let urlString = normalizedImageURLString(from: imageURL) else {
            throw apiKey.isEmpty ? QwenVisionError.missingAPIKey : QwenVisionError.invalidImage
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(makeRequestBody(imageURL: urlString, phoneNumber: phoneNumber))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let completion = try JSONDecoder().decode(QwenCompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content else {
            throw QwenVisionError.emptyResponse
        }

        let jsonText = extractJSONObject(from: content)
        guard let jsonData = jsonText.data(using: .utf8) else {
            return nil
        }

        let summary = try JSONDecoder().decode(QwenSummaryResponse.self, from: jsonData)
        let phones = summary.phones.joined(separator: "、")
        let allRecognizedText = [phones, summary.name ?? "", summary.services ?? ""].joined(separator: "、")
        let recognizedPhones = PhoneNumberExtractor.allPhoneNumbers(in: allRecognizedText).joined(separator: "、")
        let trustedPhoneText = PhoneNumberExtractor.allPhoneNumbers(in: phones).isEmpty ? phoneNumber : phones
        let result = ShopTextSummary(
            shopName: cleaned(summary.name),
            serviceContent: cleaned(summary.services),
            phoneNumber: cleaned(recognizedPhones.isEmpty ? trustedPhoneText : recognizedPhones)
        )

        return ShopTextSummarizer.refine(result, fullText: trustedPhoneText)
    }

    private static func makeRequestBody(imageURL: String, phoneNumber: String) -> QwenChatCompletionRequest {
        let prompt = """
        请识别这张裁剪后的店铺门头图片，提取店铺名称、服务内容、所有真实电话号码。
        只输出 JSON，不要 Markdown，不要解释。
        JSON 格式：{"name":"","services":"","phones":[]}
        忽略相册编辑器、截图界面、按钮、标签、水印和系统 UI 文案。
        不要把“手机专业维修”“爆屏修复”等服务大字当作店铺名称。
        店铺名称优先从门头品牌、小牌、角标、Logo 附近文字中判断。
        \(phoneNumber.isEmpty ? "" : "已知本地检测到的电话号码：\(phoneNumber)")
        如果图片里有多个相邻门店，优先选择与这些电话号码同一门头或同一背景区域的店铺。
        """

        return QwenChatCompletionRequest(
            model: model,
            messages: [
                QwenChatMessage(
                    role: "user",
                    content: [
                        .text(QwenTextContent(text: prompt)),
                        .imageURL(QwenImageURLContent(imageURL: QwenImageURL(url: imageURL)))
                    ]
                )
            ],
            temperature: 0.1
        )
    }

    private static func configuredAPIKey() -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "DashScopeAPIKey") as? String else {
            return ""
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("$(") ? "" : trimmed
    }

    private static func normalizedImageURLString(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.hasPrefix("data:image/") {
            return trimmed
        }

        if let absoluteURL = URL(string: trimmed), absoluteURL.scheme != nil {
            return absoluteURL.absoluteString
        }

        if trimmed.hasPrefix("/") {
            return "https://api.gmpebr.com\(trimmed)"
        }

        return "https://api.gmpebr.com/\(trimmed)"
    }

    private static func extractJSONObject(from value: String) -> String {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```JSON", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            return text
        }

        return String(text[start...end])
    }

    private static func cleaned(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct QwenChatCompletionRequest: Encodable {
    let model: String
    let messages: [QwenChatMessage]
    let temperature: Double
}

private struct QwenChatMessage: Codable {
    let role: String
    let content: [QwenMessageContent]
}

private enum QwenMessageContent: Codable {
    case text(QwenTextContent)
    case imageURL(QwenImageURLContent)

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(QwenTextContent(text: try container.decode(String.self, forKey: .text)))
        case "image_url":
            self = .imageURL(QwenImageURLContent(imageURL: try container.decode(QwenImageURL.self, forKey: .imageURL)))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unsupported content type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let content):
            try container.encode("text", forKey: .type)
            try container.encode(content.text, forKey: .text)
        case .imageURL(let content):
            try container.encode("image_url", forKey: .type)
            try container.encode(content.imageURL, forKey: .imageURL)
        }
    }
}

private struct QwenTextContent: Codable {
    let text: String
}

private struct QwenImageURLContent: Codable {
    let imageURL: QwenImageURL
}

private struct QwenImageURL: Codable {
    let url: String
}

private struct QwenCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}

private struct QwenSummaryResponse: Decodable {
    let name: String?
    let services: String?
    let phones: [String]

    enum CodingKeys: String, CodingKey {
        case name
        case services
        case phones
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.services = try container.decodeIfPresent(String.self, forKey: .services)
        self.phones = Self.decodePhones(from: container)
    }

    private static func decodePhones(from container: KeyedDecodingContainer<CodingKeys>) -> [String] {
        if let values = try? container.decode([String].self, forKey: .phones) {
            return values
        }

        if let values = try? container.decode([Int].self, forKey: .phones) {
            return values.map(String.init)
        }

        if let values = try? container.decode([Double].self, forKey: .phones) {
            return values.map { String(format: "%.0f", $0) }
        }

        if let value = try? container.decode(String.self, forKey: .phones) {
            return PhoneNumberExtractor.allPhoneNumbers(in: value)
        }

        if let value = try? container.decode(Int.self, forKey: .phones) {
            return [String(value)]
        }

        return []
    }
}
