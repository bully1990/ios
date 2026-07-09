import SwiftUI
import UIKit

enum ImageLoader {
    private static let remoteBaseURL = URL(string: "https://api.gmpebr.com")!

    static func image(at path: String?) -> UIImage? {
        guard let path, !path.isEmpty else {
            return nil
        }

        if FileManager.default.fileExists(atPath: path) {
            return UIImage(contentsOfFile: path)
        }

        let url = URL(fileURLWithPath: path)
        return UIImage(contentsOfFile: url.path)
    }

    static func remoteURL(for path: String?) -> URL? {
        guard let rawPath = path?.trimmingCharacters(in: .whitespacesAndNewlines), !rawPath.isEmpty else {
            return nil
        }

        if FileManager.default.fileExists(atPath: rawPath) {
            return nil
        }

        if let url = URL(string: rawPath),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return url
        }

        if rawPath.hasPrefix("/") {
            return URL(string: rawPath, relativeTo: remoteBaseURL)?.absoluteURL
        }

        if rawPath.hasPrefix("uploadfile/") {
            return URL(string: "/" + rawPath, relativeTo: remoteBaseURL)?.absoluteURL
        }

        return nil
    }
}

struct RecordThumbnail: View {
    let path: String?

    var body: some View {
        RecordImage(path: path, contentMode: .fill)
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct RecordImage: View {
    let path: String?
    let contentMode: ContentMode

    var body: some View {
        Group {
            if let image = ImageLoader.image(at: path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let url = ImageLoader.remoteURL(for: path) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    case .failure:
                        placeholder(systemImage: "photo.badge.exclamationmark")
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.thinMaterial)
                    @unknown default:
                        placeholder(systemImage: "photo")
                    }
                }
            } else {
                placeholder(systemImage: "photo")
            }
        }
    }

    private func placeholder(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.thinMaterial)
    }
}
