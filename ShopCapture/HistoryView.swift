import CoreData
import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ShopRecord.timestamp, ascending: false)],
        animation: .default
    )
    private var records: FetchedResults<ShopRecord>

    @State private var isSelecting = false
    @State private var selectedRecordIDs = Set<NSManagedObjectID>()
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView("暂无记录", systemImage: "text.viewfinder", description: Text("检测到稳定电话号码后会自动保存门头信息。"))
            } else {
                ForEach(records) { record in
                    if isSelecting {
                        Button {
                            toggleSelection(for: record)
                        } label: {
                            HistorySelectableRow(
                                record: record,
                                isSelected: selectedRecordIDs.contains(record.objectID)
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink {
                            RecordDetailView(record: record)
                        } label: {
                            HistoryRow(record: record)
                        }
                    }
                }
                .onDelete(perform: deleteRecords)
            }
        }
        .navigationTitle("历史记录")
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                selectionDeleteBar
            }
        }
        .alert("删除选中的记录？", isPresented: $isShowingDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                deleteSelectedRecords()
            }
        } message: {
            Text("将删除 \(selectedRecordIDs.count) 条历史记录，相关图片也会一起删除。")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                if records.isEmpty {
                    EmptyView()
                } else {
                    Button(isSelecting ? "取消" : "选择") {
                        isSelecting.toggle()
                        selectedRecordIDs.removeAll()
                    }
                }
            }
        }
    }

    private var selectionDeleteBar: some View {
        HStack(spacing: 12) {
            Text("已选择 \(selectedRecordIDs.count) 条")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                Label("删除所选", systemImage: "trash")
                    .font(.headline.weight(.semibold))
            }
            .disabled(selectedRecordIDs.isEmpty)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private func toggleSelection(for record: ShopRecord) {
        let id = record.objectID
        if selectedRecordIDs.contains(id) {
            selectedRecordIDs.remove(id)
        } else {
            selectedRecordIDs.insert(id)
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        for index in offsets {
            do {
                try ShopRecordStore.delete(records[index], context: viewContext)
            } catch {
                print("Warning: failed to delete record: \(error.localizedDescription)")
            }
        }
    }

    private func deleteSelectedRecords() {
        let selectedRecords = records.filter { selectedRecordIDs.contains($0.objectID) }
        for record in selectedRecords {
            do {
                try ShopRecordStore.delete(record, context: viewContext)
            } catch {
                print("Warning: failed to delete selected record: \(error.localizedDescription)")
            }
        }

        selectedRecordIDs.removeAll()
        isSelecting = false
    }
}

private struct HistorySelectableRow: View {
    @ObservedObject var record: ShopRecord
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(isSelected ? .red : .secondary)

            HistoryRow(record: record)
        }
    }
}

private struct HistoryRow: View {
    @ObservedObject var record: ShopRecord

    var body: some View {
        HStack(spacing: 12) {
            RecordThumbnail(path: record.imagePath)

            VStack(alignment: .leading, spacing: 5) {
                Text(record.shopName?.isEmpty == false ? record.shopName ?? "" : record.phoneNumber ?? "无号码")
                    .font(.headline)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(locationText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.vertical, 4)
    }

    private var locationText: String {
        if record.latitude == 0 && record.longitude == 0 {
            return "位置待补充"
        }
        return "已记录位置"
    }

    private var subtitle: String {
        if let serviceContent = record.serviceContent, !serviceContent.isEmpty {
            return serviceContent
        }

        if let phoneNumber = record.phoneNumber, !phoneNumber.isEmpty {
            return phoneNumber
        }

        return shortText
    }

    private var shortText: String {
        let text = record.fullText?.replacingOccurrences(of: "\n", with: " ") ?? ""
        guard text.count > 20 else {
            return text.isEmpty ? "无识别文字" : text
        }
        return String(text.prefix(20))
    }
}
