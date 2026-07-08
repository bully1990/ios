import UIKit
import Vision

enum ImageTextRecognizer {
    struct Result {
        let fullText: String
        let phoneNumber: String
    }

    static func detectShopFrame(in image: UIImage) async throws -> DetectedShopFrame? {
        let normalizedImage = image.normalizedForRecognition()
        guard let cgImage = normalizedImage.cgImage else {
            return nil
        }

        guard let result = try recognizeText(in: cgImage, image: normalizedImage) else {
            return nil
        }

        return DetectedShopFrame(image: image, fullText: result.fullText, phoneNumber: result.phoneNumber)
    }

    private static func recognizeText(in cgImage: CGImage, image: UIImage) throws -> Result? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["zh-Hans", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try handler.perform([request])

        let textLines = OCRTextContextBuilder.lines(from: request.results ?? [], image: image)
        let fullText = textLines.map(\.text).joined(separator: "\n")

        let phoneNumbers = PhoneNumberExtractor.allPhoneNumbers(in: fullText)
        guard !phoneNumbers.isEmpty else {
            return nil
        }
        let phoneNumber = phoneNumbers.joined(separator: "、")

        return Result(
            fullText: OCRTextContextBuilder.prioritizedText(from: textLines, phoneNumber: phoneNumber),
            phoneNumber: phoneNumber
        )
    }
}

private extension UIImage {
    func normalizedForRecognition() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
