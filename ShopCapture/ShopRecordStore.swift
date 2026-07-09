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
        guard let uploadImageData = payload.image.jpegData(compressionQuality: 0.78) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let imageURL = try writeImage(payload.image, id: id)
        let context = persistence.newBackgroundContext()
        var clientID = id
        var replacedImagePath: String?

        try await context.perform {
            let record = try findDuplicateRecord(for: payload, context: context)
                ?? NSEntityDescription.insertNewObject(forEntityName: "ShopRecord", into: context)
            let isExistingRecord = record.value(forKey: "id") != nil

            if isExistingRecord {
                if let existingID = record.value(forKey: "id") as? UUID {
                    clientID = existingID
                }
                replacedImagePath = record.value(forKey: "imagePath") as? String
            } else {
                record.setValue(id, forKey: "id")
            }

            apply(payload, imagePath: imageURL.path, to: record)

            if context.hasChanges {
                try context.save()
            }
        }

        if let replacedImagePath, replacedImagePath != imageURL.path {
            try? deleteImage(at: replacedImagePath)
        }

        let uploadPayload = ShopCaptureUploadRequest(
            clientID: clientID,
            imageData: uploadImageData,
            fullText: payload.fullText,
            phoneNumber: payload.phoneNumber,
            shopName: payload.shopName,
            serviceContent: payload.serviceContent,
            latitude: payload.latitude,
            longitude: payload.longitude,
            timestamp: payload.timestamp
        )

        Task.detached {
            do {
                try await ShopCaptureAPIClient.upload(uploadPayload)
            } catch {
                print("Warning: failed to upload shop record: \(error.localizedDescription)")
            }
        }
    }

    private static func apply(_ payload: CapturedShopPayload, imagePath: String, to record: NSManagedObject) {
        record.setValue(payload.fullText, forKey: "fullText")
        record.setValue(payload.phoneNumber, forKey: "phoneNumber")
        record.setValue(cleaned(payload.shopName), forKey: "shopName")
        record.setValue(cleaned(payload.serviceContent), forKey: "serviceContent")
        record.setValue(imagePath, forKey: "imagePath")
        record.setValue(payload.latitude, forKey: "latitude")
        record.setValue(payload.longitude, forKey: "longitude")
        record.setValue(payload.timestamp, forKey: "timestamp")
    }

    private static func findDuplicateRecord(for payload: CapturedShopPayload, context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "ShopRecord")
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        request.fetchLimit = 100

        let phoneKey = canonicalPhoneKey(payload.phoneNumber)
        let nameKey = canonicalNameKey(payload.shopName)
        guard phoneKey != nil || nameKey != nil else {
            return nil
        }

        return try context.fetch(request).first { record in
            if let phoneKey,
               canonicalPhoneKey(record.value(forKey: "phoneNumber") as? String) == phoneKey {
                return true
            }

            if let nameKey,
               canonicalNameKey(record.value(forKey: "shopName") as? String) == nameKey {
                return true
            }

            return false
        }
    }

    private static func canonicalPhoneKey(_ value: String?) -> String? {
        let numbers = PhoneNumberExtractor.allPhoneNumbers(in: value ?? "")
        guard !numbers.isEmpty else {
            return nil
        }
        return numbers.map { $0.filter(\.isNumber) }.sorted().joined(separator: "|")
    }

    private static func canonicalNameKey(_ value: String?) -> String? {
        let normalized = cleaned(value)?
            .applyingTransform(.fullwidthToHalfwidth, reverse: false)?
            .lowercased()
            .filter { !$0.isWhitespace && !$0.isPunctuation }
        return normalized?.isEmpty == false ? normalized : nil
    }

    @MainActor
    static func delete(_ record: ShopRecord, context: NSManagedObjectContext) throws {
        let imagePath = record.imagePath
        context.delete(record)

        if context.hasChanges {
            try context.save()
        }

        try deleteImage(at: imagePath)
    }

    @MainActor
    static func update(
        _ record: ShopRecord,
        shopName: String?,
        serviceContent: String?,
        phoneNumber: String?,
        fullText: String?,
        context: NSManagedObjectContext
    ) throws {
        record.setValue(cleaned(shopName), forKey: "shopName")
        record.setValue(cleaned(serviceContent), forKey: "serviceContent")
        record.setValue(cleaned(phoneNumber), forKey: "phoneNumber")
        record.setValue(cleaned(fullText), forKey: "fullText")

        if context.hasChanges {
            try context.save()
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

    private static func deleteImage(at path: String?) throws {
        guard let path, !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            return
        }

        try FileManager.default.removeItem(atPath: path)
    }

    private static func cleaned(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
