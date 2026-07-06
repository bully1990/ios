import CoreData
import Foundation
import UIKit

struct CapturedShopPayload {
    let image: UIImage
    let fullText: String
    let phoneNumber: String
    let shopName: String?
    let serviceContent: String?
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

enum ShopRecordStore {
    static func save(_ payload: CapturedShopPayload, persistence: PersistenceController = .shared) async throws {
        let id = UUID()
        let imageURL = try writeImage(payload.image, id: id)
        let context = persistence.newBackgroundContext()

        try await context.perform {
            let record = NSEntityDescription.insertNewObject(forEntityName: "ShopRecord", into: context)
            record.setValue(id, forKey: "id")
            record.setValue(payload.fullText, forKey: "fullText")
            record.setValue(payload.phoneNumber, forKey: "phoneNumber")
            record.setValue(payload.shopName, forKey: "shopName")
            record.setValue(payload.serviceContent, forKey: "serviceContent")
            record.setValue(imageURL.path, forKey: "imagePath")
            record.setValue(payload.latitude, forKey: "latitude")
            record.setValue(payload.longitude, forKey: "longitude")
            record.setValue(payload.timestamp, forKey: "timestamp")

            if context.hasChanges {
                try context.save()
            }
        }
    }

    private static func writeImage(_ image: UIImage, id: UUID) throws -> URL {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let directory = try imageDirectory()
        let finalURL = directory.appendingPathComponent("\(id.uuidString).jpg")
        let temporaryURL = directory.appendingPathComponent("\(id.uuidString).tmp")

        try jpegData.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: finalURL.path) {
            try FileManager.default.removeItem(at: finalURL)
        }

        try FileManager.default.moveItem(at: temporaryURL, to: finalURL)
        return finalURL
    }

    private static func imageDirectory() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = documents.appendingPathComponent("ShopImages", isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }
}
