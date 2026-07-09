import Foundation

struct ShopTextSummary {
    let shopName: String?
    let serviceContent: String?
    let phoneNumber: String?

    var hasUsefulContent: Bool {
        shopName?.isEmpty == false || serviceContent?.isEmpty == false
    }

    init(shopName: String?, serviceContent: String?, phoneNumber: String? = nil) {
        self.shopName = shopName
        self.serviceContent = serviceContent
        self.phoneNumber = phoneNumber
    }
}

enum ShopTextSummarizer {
    static func summarizeLocally(fullText: String, phoneNumber: String) -> ShopTextSummary? {
        let focusedText = focusedText(from: fullText) ?? fullText
        let lines = normalizedLines(from: focusedText)
        guard !lines.isEmpty else {
            return nil
        }

        let detectedName = candidateName(from: lines, phoneNumber: phoneNumber)
        let services = candidateServices(from: lines, excluding: detectedName, phoneNumber: phoneNumber)
        let shopName = detectedName ?? fallbackName(from: services)
        let result = ShopTextSummary(shopName: shopName, serviceContent: services)

        return refine(result, fullText: fullText)
    }

    static func ensureName(_ summary: ShopTextSummary?) -> ShopTextSummary? {
        refine(summary, fullText: nil)
    }

    static func refine(_ summary: ShopTextSummary?, fullText: String?) -> ShopTextSummary? {
        guard let summary else {
            return nil
        }

        let serviceContent = formattedServiceContent(summary.serviceContent)
        let shopName = summary.shopName ?? fallbackName(from: serviceContent)
        let result = ShopTextSummary(shopName: shopName, serviceContent: serviceContent, phoneNumber: summary.phoneNumber)

        return result.hasUsefulContent ? result : nil
    }

    private static func normalizedLines(from text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .replacingOccurrences(of: "：", with: ":")
                    .replacingOccurrences(of: "一", with: " ")
                    .replacingOccurrences(of: "—", with: " ")
                    .replacingOccurrences(of: "-", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }

    private static func focusedText(from text: String) -> String? {
        guard let markerRange = text.range(of: "同背景候选区域") else {
            return nil
        }

        let afterMarker = text[markerRange.upperBound...]
        let sectionBody = afterMarker
            .components(separatedBy: "全部OCR文本")
            .first?
            .replacingOccurrences(of: "（优先参考，与电话行背景颜色接近）:", with: "")
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let sectionBody, !sectionBody.isEmpty else {
            return nil
        }

        return sectionBody
    }

    private static func candidateName(from lines: [String], phoneNumber: String) -> String? {
        let usefulLines = lines.filter { !isPhoneLine($0, phoneNumber: phoneNumber) }

        if let trailingName = usefulLines.last(where: { isLikelyName($0) && !isLikelyService($0) }) {
            return trailingName
        }

        if let companyName = usefulLines.first(where: { line in
            ["公司", "店", "厂", "经营部", "商行", "中心", "门市", "维修部"].contains { line.contains($0) }
        }) {
            return companyName
        }

        return usefulLines.first(where: isLikelyName)
    }

    private static func candidateServices(from lines: [String], excluding shopName: String?, phoneNumber: String) -> String? {
        let serviceLines = lines
            .filter { line in
                line != shopName && !isPhoneLine(line, phoneNumber: phoneNumber) && isLikelyService(line)
            }
            .prefix(4)

        let services = serviceLines.joined(separator: "；")
        return services.isEmpty ? nil : services
    }

    private static func formattedServiceContent(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalized = value
            .replacingOccurrences(of: "，", with: "、")
            .replacingOccurrences(of: ",", with: "、")
            .replacingOccurrences(of: "；", with: "、")
            .replacingOccurrences(of: ";", with: "、")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            return nil
        }

        let explicitParts = normalized
            .components(separatedBy: CharacterSet(charactersIn: "、 \n\t"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if explicitParts.count > 1 {
            return explicitParts.joined(separator: "、")
        }

        let compact = normalized.replacingOccurrences(of: "、", with: "")
        let serviceTerms = [
            "爆屏修复", "手机维修", "专业维修", "手机专业维修", "手机配件",
            "数码相机", "新机", "二手", "配件", "批发", "回收", "维修",
            "代购", "换屏", "贴膜", "解锁", "数据恢复", "扩容", "刷机",
            "加工", "安装", "订做", "定做", "订制", "定制", "剪折弯",
            "激光切割", "切割", "焊接", "钣金"
        ]

        var remaining = compact
        var parts: [String] = []

        while !remaining.isEmpty {
            if let matched = serviceTerms.first(where: { remaining.hasPrefix($0) }) {
                parts.append(matched)
                remaining.removeFirst(matched.count)
            } else {
                let character = remaining.removeFirst()
                if parts.isEmpty {
                    parts.append(String(character))
                } else {
                    parts[parts.count - 1].append(character)
                }
            }
        }

        return parts.count > 1 ? parts.joined(separator: "、") : normalized
    }

    private static func isPhoneLine(_ line: String, phoneNumber: String) -> Bool {
        let digits = line.filter(\.isNumber)
        let phoneNumbers = phoneNumbers(from: phoneNumber)
        return line.contains("电话") || phoneNumbers.contains { digits.contains($0) }
    }

    private static func phoneNumbers(from value: String) -> [String] {
        var numbers: [String] = []
        var current = ""

        for character in value {
            if character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                numbers.append(current)
                current = ""
            }
        }

        if !current.isEmpty {
            numbers.append(current)
        }

        return numbers
    }

    private static func isLikelyName(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        return compact.count >= 2 && compact.count <= 12 && !compact.contains(":")
    }

    private static func isLikelyService(_ line: String) -> Bool {
        let keywords = [
            "加工", "维修", "回收", "安装", "订做", "定做", "订制", "定制",
            "剪", "折弯", "激光", "切割", "焊接", "钣金", "铁板", "冷轧板",
            "不锈钢", "机箱", "机柜", "门窗", "招牌", "广告", "开锁", "搬家"
        ]

        return keywords.contains { line.contains($0) }
    }

    private static func fallbackName(from services: String?) -> String? {
        guard let services, !services.isEmpty else {
            return nil
        }

        let keywords = [
            "钣金", "激光切割", "切割", "折弯", "焊接", "机箱", "机柜",
            "不锈钢", "铁板", "冷轧板", "维修", "安装", "回收", "广告", "招牌"
        ]
        let matched = keywords.filter { services.contains($0) }

        if matched.contains("钣金"), matched.contains("激光切割") || matched.contains("切割") {
            return "钣金切割加工"
        }

        if matched.contains("钣金"), matched.contains("折弯") {
            return "钣金折弯加工"
        }

        if matched.contains("焊接"), matched.contains("机箱") || matched.contains("机柜") {
            return "机箱焊接加工"
        }

        if let first = matched.first {
            return "\(first)服务"
        }

        let compact = services
            .components(separatedBy: CharacterSet(charactersIn: "；、,， "))
            .first?
            .filter { !$0.isNumber }
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !compact.isEmpty else {
            return nil
        }

        return String(compact.prefix(8))
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

        return ShopTextSummarizer.refine(result, fullText: fullText)
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
        如果 OCR 里有多个相邻店铺招牌，优先选择与电话号码和服务内容在同一门头区域的主招牌名称，不要选择旁边相邻店铺名称。
        如果 OCR 文本包含“同背景候选区域”，说明这些文字背后的招牌颜色与电话行更接近，请优先从该区域判断店名和服务内容。
        餐饮门头中，如果服务词与电话同区域，店名优先取该区域的大字主招牌。
        输出严格 JSON，不要 Markdown，不要解释。
        JSON 字段：
        - name: 店铺/公司/门头名称，无法判断则为空字符串
        - services: 主要服务内容，保留门头上服务词之间的空格关系，多个服务用顿号分隔，无法判断则为空字符串

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
