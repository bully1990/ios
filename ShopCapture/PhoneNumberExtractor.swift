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

    private static func isPlausible(_ candidate: String, allowsLandline: Bool) -> Bool {
        let digits = candidate.filter(\.isNumber)

        if digits.count == 11,
           digits.hasPrefix("1"),
           let secondDigit = digits.dropFirst().first,
           "3456789".contains(secondDigit) {
            return true
        }

        if allowsLandline, isValidLandline(digits) {
            return true
        }

        return false
    }

    private static func isValidLandline(_ digits: String) -> Bool {
        guard digits.hasPrefix("0"), digits.count >= 10, digits.count <= 12 else {
            return false
        }

        let threeDigitAreaCodes: Set<String> = ["010", "020", "021", "022", "023", "024", "025", "027", "028", "029"]
        if digits.count >= 10,
           threeDigitAreaCodes.contains(String(digits.prefix(3))),
           (7...8).contains(digits.count - 3) {
            return true
        }

        guard digits.count >= 11,
              let areaCode = Int(digits.prefix(4)),
              (7...8).contains(digits.count - 4) else {
            return false
        }

        return validFourDigitAreaCodeRanges.contains { $0.contains(areaCode) }
    }

    private static let validFourDigitAreaCodeRanges: [ClosedRange<Int>] = [
        0310...0319, 0335...0335, 0349...0349, 0350...0359, 0370...0379, 0391...0398,
        0410...0419, 0421...0429, 0431...0439, 0451...0459, 0464...0469, 0470...0479, 0482...0483,
        0510...0527, 0530...0539, 0543...0546, 0550...0559, 0561...0566, 0570...0580, 0591...0599,
        0631...0635, 0660...0668, 0691...0692, 0701...0701, 0710...0728, 0730...0739, 0743...0746,
        0750...0769, 0770...0779, 0790...0799, 0812...0818, 0825...0827, 0830...0839, 0851...0859,
        0870...0879, 0883...0888, 0891...0899, 0901...0909, 0910...0919, 0930...0939, 0941...0943,
        0951...0955, 0970...0979, 0990...0999
    ]
}
