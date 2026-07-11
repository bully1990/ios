import Foundation
import UIKit

enum ShopCaptureAPIClient {
    private static let endpoint = URL(string: "https://api.gmpebr.com/index.php?m=content&c=shop_capture&a=save_record")!

    @discardableResult
    static func upload(_ requestPayload: ShopCaptureUploadRequest) async throws -> ShopCaptureUploadResponse {
        let body = UploadPayload(
            clientUUID: requestPayload.clientID.uuidString,
            shopName: requestPayload.shopName,
            serviceContent: requestPayload.serviceContent,
            phoneNumber: requestPayload.phoneNumber,
            fullText: requestPayload.fullText,
            latitude: requestPayload.latitude,
            longitude: requestPayload.longitude,
            captureTime: Int(requestPayload.timestamp.timeIntervalSince1970),
            imageBase64: requestPayload.imageData?.base64EncodedString(),
            source: "ios"
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        UserAPIClient.applyAuthentication(to: &request)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let envelope = try JSONDecoder().decode(APIEnvelope<ShopCaptureUploadResponse>.self, from: data)
        guard envelope.normalizedCode == 200 else {
            throw URLError(.cannotParseResponse)
        }

        return envelope.data
    }
}

struct ShopCaptureUploadRequest: Sendable {
    let clientID: UUID
    let imageData: Data?
    let fullText: String
    let phoneNumber: String
    let shopName: String?
    let serviceContent: String?
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

struct ShopCaptureUploadResponse: Decodable, Sendable {
    let id: Int
    let clientUUID: String
    let imageURL: String
    let auditStatus: Int

    enum CodingKeys: String, CodingKey {
        case id
        case clientUUID = "client_uuid"
        case imageURL = "image_url"
        case auditStatus = "audit_status"
    }
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
    let imageBase64: String?
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

private struct APIEnvelope<T: Decodable>: Decodable {
    let code: FlexibleInt
    let data: T

    var normalizedCode: Int {
        code.value
    }
}

private enum FlexibleInt: Decodable {
    case int(Int)
    case string(String)

    var value: Int {
        switch self {
        case .int(let value):
            return value
        case .string(let value):
            return Int(value) ?? 0
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }
        self = .string((try? container.decode(String.self)) ?? "")
    }
}
