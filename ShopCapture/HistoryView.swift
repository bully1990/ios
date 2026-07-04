import CoreData
import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss

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
            }
        }
        .navigationTitle("历史记录")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("关闭") {
                    dismiss()
                }
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
                Text(record.phoneNumber ?? "无号码")
                    .font(.headline)
                    .lineLimit(1)

                Text(shortText)
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

    private var shortText: String {
        let text = record.fullText?.replacingOccurrences(of: "\n", with: " ") ?? ""
        guard text.count > 20 else {
            return text.isEmpty ? "无识别文字" : text
        }
        return String(text.prefix(20))
    }
}
