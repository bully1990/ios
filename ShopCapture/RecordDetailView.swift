import CoreLocation
import MapKit
import SwiftUI

struct RecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var record: ShopRecord
    @State private var isShowingDeleteConfirmation = false
    @State private var isEditing = false
    @State private var draftShopName = ""
    @State private var draftServiceContent = ""
    @State private var draftPhoneNumber = ""
    @State private var draftFullText = ""

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

                VStack(alignment: .leading, spacing: 10) {
                    Text("完整识别文字")
                        .font(.headline)

                    if isEditing {
                        TextEditor(text: $draftFullText)
                            .frame(minHeight: 160)
                            .padding(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(.secondary.opacity(0.25))
                            )
                    } else {
                        Text(record.fullText?.isEmpty == false ? record.fullText ?? "" : "无识别文字")
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
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
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("保存") {
                        saveEdits()
                    }
                    .fontWeight(.semibold)
                } else {
                    Menu {
                        Button {
                            beginEditing()
                        } label: {
                            Label("编辑内容", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog("删除这条历史记录？", isPresented: $isShowingDeleteConfirmation, titleVisibility: .visible) {
            Button("删除记录", role: .destructive) {
                deleteRecord()
            }

            Button("取消", role: .cancel) {
            }
        } message: {
            Text("删除后会同时移除保存的门头图片。")
        }
    }

    private var summaryFields: some View {
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
                Label(timestamp.formatted(date: .abbreviated, time: .standard), systemImage: "calendar")
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
        }
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

    private func deleteRecord() {
        do {
            try ShopRecordStore.delete(record, context: viewContext)
            dismiss()
        } catch {
            print("Warning: failed to delete record: \(error.localizedDescription)")
        }
    }

    private func beginEditing() {
        resetDraft()
        isEditing = true
    }

    private func cancelEditing() {
        resetDraft()
        isEditing = false
    }

    private func resetDraft() {
        draftShopName = record.shopName ?? ""
        draftServiceContent = record.serviceContent ?? ""
        draftPhoneNumber = record.phoneNumber ?? ""
        draftFullText = record.fullText ?? ""
    }

    private func saveEdits() {
        do {
            try ShopRecordStore.update(
                record,
                shopName: draftShopName,
                serviceContent: draftServiceContent,
                phoneNumber: draftPhoneNumber,
                fullText: draftFullText,
                context: viewContext
            )
            isEditing = false
        } catch {
            print("Warning: failed to update record: \(error.localizedDescription)")
        }
    }
}
