import Foundation

enum PhoneNumberExtractor {
    private static let mobilePattern = #"(?<!\d)1[3-9]\d[\s-]?\d{4}[\s-]?\d{4}(?!\d)"#
    private static let landlinePattern = #"(?<!\d)(?:0\d{2,3}[\s-]?)?\d{7,8}(?:[\s-]?(?:转|ext\.?|#)\s?\d{1,6})?(?!\d)"#

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

            let candidate = String(normalized[swiftRange])
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")

            if isPlausible(candidate) {
                return candidate
            }
        }

        return nil
    }

    private static func normalizeOCRText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "o", with: "0")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "l", with: "1")
            .replacingOccurrences(of: "｜", with: "1")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: " ", with: " ")
    }

    private static func isPlausible(_ candidate: String) -> Bool {
        let digits = candidate.filter(\.isNumber)

        if digits.count == 11, digits.hasPrefix("1") {
            return true
        }

        if digits.count >= 7, digits.count <= 13 {
            return true
        }

        return false
    }
}
