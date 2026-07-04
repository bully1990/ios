import SwiftUI
import UIKit

enum ImageLoader {
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
}

struct RecordThumbnail: View {
    let path: String?

    var body: some View {
        Group {
            if let image = ImageLoader.image(at: path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.thinMaterial)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
