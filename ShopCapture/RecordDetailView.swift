import CoreLocation
import MapKit
import SwiftUI

struct RecordDetailView: View {
    @ObservedObject var record: ShopRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let image = ImageLoader.image(at: record.imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    ContentUnavailableView("图片不可用", systemImage: "photo.badge.exclamationmark")
                        .frame(minHeight: 220)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(record.shopName?.isEmpty == false ? record.shopName ?? "" : "未整理出名称", systemImage: "storefront")
                        .font(.headline)

                    Label(record.serviceContent?.isEmpty == false ? record.serviceContent ?? "" : "未整理出服务内容", systemImage: "text.badge.checkmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label(record.phoneNumber ?? "无号码", systemImage: "phone")
                        .font(.subheadline)

                    Label(String(format: "纬度 %.8f，经度 %.8f", record.latitude, record.longitude), systemImage: "location")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let timestamp = record.timestamp {
                        Label(timestamp.formatted(date: .abbreviated, time: .standard), systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Map(position: .constant(mapPosition)) {
                    Marker("门头位置", coordinate: coordinate)
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text("完整识别文字")
                        .font(.headline)

                    Text(record.fullText?.isEmpty == false ? record.fullText ?? "" : "无识别文字")
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude)
    }

    private var mapPosition: MapCameraPosition {
        return .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }
}
