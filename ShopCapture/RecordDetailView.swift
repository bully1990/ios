import CoreLocation
import MapKit
import SwiftUI

struct ShopDetailRecord {
    let imagePath: String?
    let shopName: String
    let serviceContent: String
    let phoneNumber: String
    let latitude: Double
    let longitude: Double
    let timestamp: Date?
    let statusTitle: String?
    let statusColor: Color
}

struct ShopRecordDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let canModify: Bool
    let onSave: ((String, String, String) async throws -> ShopDetailRecord)?
    let onDelete: (() async throws -> Void)?

    @State private var record: ShopDetailRecord
    @State private var isShowingDeleteConfirmation = false
    @State private var isEditing = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var draftShopName = ""
    @State private var draftServiceContent = ""
    @State private var draftPhoneNumber = ""

    init(
        record: ShopDetailRecord,
        canModify: Bool,
        onSave: ((String, String, String) async throws -> ShopDetailRecord)? = nil,
        onDelete: (() async throws -> Void)? = nil
    ) {
        self.canModify = canModify
        self.onSave = onSave
        self.onDelete = onDelete
        _record = State(initialValue: record)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RecordImage(path: record.imagePath, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if let statusTitle = record.statusTitle {
                    Label(statusTitle, systemImage: "checkmark.seal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(record.statusColor)
                }

                if isEditing {
                    editableFields
                } else {
                    summaryFields
                }

                Map(position: .constant(mapPosition)) {
                    Marker("门头位置", coordinate: coordinate)
                }
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button {
                    openDirections()
                } label: {
                    Label("导航到目的地", systemImage: "map.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(hasValidLocation ? Color.accentColor : Color.gray.opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .disabled(!hasValidLocation || isWorking)
            }
            .padding()
        }
        .navigationTitle("详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isEditing {
                    Button("取消") {
                        cancelEditing()
                    }
                    .disabled(isWorking)
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("保存") {
                        Task { await saveEdits() }
                    }
                    .fontWeight(.semibold)
                    .disabled(isWorking)
                } else if canModify, onSave != nil || onDelete != nil {
                    Menu {
                        if onSave != nil {
                            Button {
                                beginEditing()
                            } label: {
                                Label("编辑内容", systemImage: "pencil")
                            }
                        }

                        if onDelete != nil {
                            Button(role: .destructive) {
                                isShowingDeleteConfirmation = true
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(isWorking)
                }
            }
        }
        .confirmationDialog("删除这条店铺记录？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("删除记录", role: .destructive) {
                Task { await deleteRecord() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后将无法恢复。")
        }
        .alert("操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "请稍后重试")
        }
        .overlay {
            if isWorking {
                ProgressView()
                    .padding(18)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private var summaryFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(record.shopName.isEmpty ? "未整理出名称" : record.shopName, systemImage: "storefront")
                .font(.headline)

            Label(record.serviceContent.isEmpty ? "未整理出服务内容" : record.serviceContent, systemImage: "text.badge.checkmark")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(record.phoneNumber.isEmpty ? "无号码" : record.phoneNumber, systemImage: "phone")
                .font(.subheadline)

            Label(String(format: "纬度 %.8f，经度 %.8f", record.latitude, record.longitude), systemImage: "location")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let timestamp = record.timestamp {
                Label(ShopDateFormatter.dateTime(timestamp), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var editableFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            editableTextField(title: "名称", text: $draftShopName)
            editableTextField(title: "服务内容", text: $draftServiceContent)
            editableTextField(title: "电话", text: $draftPhoneNumber)

            Label(String(format: "纬度 %.8f，经度 %.8f", record.latitude, record.longitude), systemImage: "location")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let timestamp = record.timestamp {
                Label(ShopDateFormatter.dateTime(timestamp), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func editableTextField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField(title, text: text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(isWorking)
        }
    }

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude)
    }

    private var mapPosition: MapCameraPosition {
        .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }

    private var hasValidLocation: Bool {
        record.latitude != 0 && record.longitude != 0
    }

    private func openDirections() {
        guard hasValidLocation else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = record.shopName.isEmpty ? "门店位置" : record.shopName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func beginEditing() {
        draftShopName = record.shopName
        draftServiceContent = record.serviceContent
        draftPhoneNumber = record.phoneNumber
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
    }

    @MainActor
    private func saveEdits() async {
        guard let onSave else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            record = try await onSave(draftShopName, draftServiceContent, draftPhoneNumber)
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteRecord() async {
        guard let onDelete else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await onDelete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct RecordDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var record: ShopRecord

    var body: some View {
        ShopRecordDetailView(
            record: detailRecord,
            canModify: true,
            onSave: { shopName, serviceContent, phoneNumber in
                try ShopRecordStore.update(
                    record,
                    shopName: shopName,
                    serviceContent: serviceContent,
                    phoneNumber: phoneNumber,
                    fullText: record.fullText,
                    context: viewContext
                )
                return detailRecord
            },
            onDelete: {
                try ShopRecordStore.delete(record, context: viewContext)
            }
        )
    }

    private var detailRecord: ShopDetailRecord {
        ShopDetailRecord(
            imagePath: record.imagePath,
            shopName: record.shopName ?? "",
            serviceContent: record.serviceContent ?? "",
            phoneNumber: record.phoneNumber ?? "",
            latitude: record.latitude,
            longitude: record.longitude,
            timestamp: record.timestamp,
            statusTitle: nil,
            statusColor: .secondary
        )
    }
}
