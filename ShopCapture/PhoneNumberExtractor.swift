import Foundation

enum PhoneNumberExtractor {
    private static let separatorPattern = #"[\s\-–—－·.]*"#
    private static let mobilePattern = #"(?<!\d)1"# + separatorPattern + #"[3-9]"# + separatorPattern + #"\d(?:"# + separatorPattern + #"\d){8}(?!\d)"#
    private static let landlinePattern = #"(?<!\d)0\d{2,3}"# + separatorPattern + #"\d{7,8}(?:"# + separatorPattern + #"(?:转|ext\.?|#)"# + separatorPattern + #"\d{1,6})?(?!\d)"#

    static func firstPhoneNumber(in text: String) -> String? {
        let normalized = normalizeOCRText(text)
        let patterns = [mobilePattern, landlinePattern]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
            guard let match = regex.firstMatch(in: normalized, options: [], range: range),
                  let swiftRange = Range(match.range, in: normalized) else {
                continue
            }

            let candidate = String(normalized[swiftRange].filter(\.isNumber))

            if pattern == landlinePattern,
               !hasPhoneContext(near: match.range, in: normalized) {
                continue
            }

            if isPlausible(candidate, allowsLandline: pattern == landlinePattern) {
                return candidate
            }
        }

        for candidate in numericRuns(in: normalized) {
            if isPlausible(candidate, allowsLandline: false) {
                return candidate
            }
        }

        return nil
    }

    private static func normalizeOCRText(_ text: String) -> String {
        let halfWidthText = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text

        return halfWidthText
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "o", with: "0")
            .replacingOccurrences(of: "D", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "l", with: "1")
            .replacingOccurrences(of: "|", with: "1")
            .replacingOccurrences(of: "｜", with: "1")
            .replacingOccurrences(of: "Z", with: "2")
            .replacingOccurrences(of: "z", with: "2")
            .replacingOccurrences(of: "S", with: "5")
            .replacingOccurrences(of: "s", with: "5")
            .replacingOccurrences(of: "B", with: "8")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: " ", with: " ")
    }

    private static func numericRuns(in text: String) -> [String] {
        var runs: [String] = []
        var current = ""

        for character in text {
            if character.isNumber {
                current.append(character)
            } else if isSoftSeparator(character), !current.isEmpty {
                continue
            } else {
                appendCurrentRun(&current, to: &runs)
            }
        }

        appendCurrentRun(&current, to: &runs)
        return runs
    }

    private static func appendCurrentRun(_ current: inout String, to runs: inout [String]) {
        if current.count >= 7 {
            runs.append(current)
        }

        current = ""
    }

    private static func isSoftSeparator(_ character: Character) -> Bool {
        character.isWhitespace || "-–—－·.()（）:：".contains(character)
    }

    private static func hasPhoneContext(near range: NSRange, in text: String) -> Bool {
        let nsText = text as NSString
        let lineRange = nsText.lineRange(for: range)
        let line = nsText.substring(with: lineRange)
        let keywords = ["电话", "联系", "热线", "手机", "座机", "订餐", "外卖", "客服", "咨询"]
        return keywords.contains { line.contains($0) }
    }

    private static func isPlausible(_ candidate: String, allowsLandline: Bool) -> Bool {
        let digits = candidate.filter(\.isNumber)

        if digits.count == 11,
           digits.hasPrefix("1"),
           let secondDigit = digits.dropFirst().first,
           "3456789".contains(secondDigit) {
            return true
        }

        if allowsLandline, digits.hasPrefix("0"), digits.count >= 10, digits.count <= 13 {
            return true
        }

        return false
    }
}
