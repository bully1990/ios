import UIKit
import Vision

enum ImageTextRecognizer {
    static func detectShopFrame(in image: UIImage) async throws -> DetectedShopFrame? {
        guard let cgImage = image.normalizedForRecognition().cgImage else {
            return nil
        }

        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["zh-Hans", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            try handler.perform([request])

            let lines = request.results?.compactMap { observation in
                observation.topCandidates(1).first?.string
            } ?? []
            let fullText = lines.joined(separator: "\n")

            guard let phoneNumber = PhoneNumberExtractor.firstPhoneNumber(in: fullText) else {
                return nil
            }

            return DetectedShopFrame(image: image, fullText: fullText, phoneNumber: phoneNumber)
        }.value
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
