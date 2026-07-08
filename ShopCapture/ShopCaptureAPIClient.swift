import Foundation
import UIKit

enum ShopCaptureAPIClient {
    private static let endpoint = URL(string: "https://api.gmpebr.com/index.php?m=content&c=shop_capture&a=ajax_save_record")!

    static func upload(_ requestPayload: ShopCaptureUploadRequest) async throws {
        let body = UploadPayload(
            clientUUID: requestPayload.clientID.uuidString,
            shopName: requestPayload.shopName,
            serviceContent: requestPayload.serviceContent,
            phoneNumber: requestPayload.phoneNumber,
            fullText: requestPayload.fullText,
            latitude: requestPayload.latitude,
            longitude: requestPayload.longitude,
            captureTime: Int(requestPayload.timestamp.timeIntervalSince1970),
            imageBase64: requestPayload.imageData.base64EncodedString(),
            source: "ios"
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

struct ShopCaptureUploadRequest: Sendable {
    let clientID: UUID
    let imageData: Data
    let fullText: String
    let phoneNumber: String
    let shopName: String?
    let serviceContent: String?
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

private struct UploadPayload: Encodable, Sendable {
    let clientUUID: String
    let shopName: String?
    let serviceContent: String?
    let phoneNumber: String
    let fullText: String
    let latitude: Double
    let longitude: Double
    let captureTime: Int
    let imageBase64: String
    let source: String

    enum CodingKeys: String, CodingKey {
        case clientUUID = "client_uuid"
        case shopName = "shop_name"
        case serviceContent = "service_content"
        case phoneNumber = "phone_number"
        case fullText = "full_text"
        case latitude
        case longitude
        case captureTime = "capture_time"
        case imageBase64 = "image_base64"
        case source
    }
}
