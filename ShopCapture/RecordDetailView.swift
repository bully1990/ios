import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct RecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var record: ShopRecord
    @State private var isShowingDeleteConfirmation = false
    @State private var isEditing = false
    @State private var draftShopName = ""
    @State private var draftServiceContent = ""
    @State private var draftPhoneNumber = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RecordImage(path: record.imagePath, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!hasValidLocation)
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

    private var hasValidLocation: Bool {
        record.latitude != 0 && record.longitude != 0
    }

    private func openDirections() {
        guard hasValidLocation else {
            return
        }

        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = record.shopName?.isEmpty == false ? record.shopName : "门店位置"
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
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
    }

    private func saveEdits() {
        do {
            try ShopRecordStore.update(
                record,
                shopName: draftShopName,
                serviceContent: draftServiceContent,
                phoneNumber: draftPhoneNumber,
                fullText: record.fullText,
                context: viewContext
            )
            isEditing = false
        } catch {
            print("Warning: failed to update record: \(error.localizedDescription)")
        }
    }
}
