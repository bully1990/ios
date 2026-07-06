import CoreImage
import Foundation
import UIKit
import Vision

struct OCRBackgroundColor: Equatable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    func distance(to other: OCRBackgroundColor) -> CGFloat {
        let redDelta = red - other.red
        let greenDelta = green - other.green
        let blueDelta = blue - other.blue
        return sqrt(redDelta * redDelta + greenDelta * greenDelta + blueDelta * blueDelta)
    }
}

struct OCRTextLine: Equatable {
    let text: String
    let boundingBox: CGRect
    let backgroundColor: OCRBackgroundColor?
}

enum OCRTextContextBuilder {
    private static let sameBackgroundThreshold: CGFloat = 0.32

    static func lines(from observations: [VNRecognizedTextObservation], image: UIImage? = nil) -> [OCRTextLine] {
        let sortedObservations = observations.sorted { first, second in
            if abs(first.boundingBox.midY - second.boundingBox.midY) > 0.02 {
                return first.boundingBox.midY > second.boundingBox.midY
            }

            return first.boundingBox.minX < second.boundingBox.minX
        }

        return sortedObservations.compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return nil
            }

            return OCRTextLine(
                text: text,
                boundingBox: observation.boundingBox,
                backgroundColor: backgroundColor(around: observation.boundingBox, in: image)
            )
        }
    }

    static func prioritizedText(from lines: [OCRTextLine], phoneNumber: String) -> String {
        let allText = lines.map(\.text).joined(separator: "\n")
        let primaryLines = sameBackgroundLines(from: lines, phoneNumber: phoneNumber)
        let primaryText = primaryLines.map(\.text).joined(separator: "\n")

        guard !primaryText.isEmpty, primaryText != allText else {
            return allText
        }

        return """
        同背景候选区域（优先参考，与电话行背景颜色接近）:
        \(primaryText)

        全部OCR文本:
        \(allText)
        """
    }

    private static func sameBackgroundLines(from lines: [OCRTextLine], phoneNumber: String) -> [OCRTextLine] {
        guard let phoneLine = lines.first(where: { isPhoneLine($0.text, phoneNumber: phoneNumber) }) else {
            return []
        }

        let colorMatchedLines: [OCRTextLine]
        if let phoneColor = phoneLine.backgroundColor {
            colorMatchedLines = lines.filter { line in
                guard let lineColor = line.backgroundColor else {
                    return false
                }

                return lineColor.distance(to: phoneColor) <= sameBackgroundThreshold
                    && isSpatiallyRelated(line.boundingBox, to: phoneLine.boundingBox)
            }
        } else {
            colorMatchedLines = []
        }

        if colorMatchedLines.count > 1 {
            return colorMatchedLines
        }

        return lines.filter { isNear($0.boundingBox, to: phoneLine.boundingBox) }
    }

    private static func isPhoneLine(_ text: String, phoneNumber: String) -> Bool {
        let digits = text.filter(\.isNumber)
        return text.contains("电话") || (!phoneNumber.isEmpty && digits == phoneNumber)
    }

    private static func isSpatiallyRelated(_ rect: CGRect, to phoneRect: CGRect) -> Bool {
        let horizontalDistance = abs(rect.midX - phoneRect.midX)
        let verticalDistance = abs(rect.midY - phoneRect.midY)
        return horizontalDistance < 0.45 && verticalDistance < 0.55
    }

    private static func isNear(_ rect: CGRect, to phoneRect: CGRect) -> Bool {
        let horizontalDistance = abs(rect.midX - phoneRect.midX)
        let verticalDistance = abs(rect.midY - phoneRect.midY)
        return horizontalDistance < 0.35 && verticalDistance < 0.35
    }

    private static func backgroundColor(around boundingBox: CGRect, in image: UIImage?) -> OCRBackgroundColor? {
        guard let cgImage = image?.cgImage else {
            return nil
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let sampleRect = expanded(boundingBox, byX: 0.04, byY: 0.025)
        let ciRect = CGRect(
            x: sampleRect.minX * imageSize.width,
            y: sampleRect.minY * imageSize.height,
            width: sampleRect.width * imageSize.width,
            height: sampleRect.height * imageSize.height
        )

        guard ciRect.width >= 1, ciRect.height >= 1 else {
            return nil
        }

        let inputImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIAreaAverage") else {
            return nil
        }

        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: ciRect), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else {
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext().render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return OCRBackgroundColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255
        )
    }

    private static func expanded(_ rect: CGRect, byX xInset: CGFloat, byY yInset: CGFloat) -> CGRect {
        let expandedRect = rect.insetBy(dx: -xInset, dy: -yInset)
        let minX = max(0, expandedRect.minX)
        let minY = max(0, expandedRect.minY)
        let maxX = min(1, expandedRect.maxX)
        let maxY = min(1, expandedRect.maxY)
        return CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }
}
