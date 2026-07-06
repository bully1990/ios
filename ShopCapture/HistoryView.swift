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

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView("暂无记录", systemImage: "text.viewfinder", description: Text("检测到稳定电话号码后会自动保存门头信息。"))
            } else {
                ForEach(records) { record in
                    NavigationLink {
                        RecordDetailView(record: record)
                    } label: {
                        HistoryRow(record: record)
                    }
                }
                .onDelete(perform: deleteRecords)
            }
        }
        .navigationTitle("历史记录")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("关闭") {
                    dismiss()
                }
            }
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

                Text(String(format: "纬度 %.6f  经度 %.6f", record.latitude, record.longitude))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.vertical, 4)
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
