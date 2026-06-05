import SwiftUI

struct PipelineDebugLogListView: View {
    @State private var entries: [PipelineLogSummary] = []
    @State private var showingDeleteAll = false

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "ログなし",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("パイプラインログを有効にして返信提案を実行すると、ここに表示されます。")
                )
            } else {
                List {
                    ForEach(entries) { entry in
                        NavigationLink {
                            PipelineDebugLogDetailView(fileURL: entry.fileURL)
                        } label: {
                            logRow(entry)
                        }
                    }
                    .onDelete(perform: deleteEntries)
                }
            }
        }
        .navigationTitle("パイプラインログ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("全削除", role: .destructive) {
                        showingDeleteAll = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .alert("全てのログを削除しますか？", isPresented: $showingDeleteAll) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                PipelineDebugLogger.shared.deleteAll()
                entries = []
            }
        }
        .onAppear {
            entries = PipelineDebugLogger.shared.listEntries()
        }
    }

    private func logRow(_ entry: PipelineLogSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.userGoal)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                Spacer()
                if entry.hasError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                }
            }

            HStack(spacing: 8) {
                Text("\(entry.selfName) → \(entry.partnerName)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text(String(format: "%.1fs", entry.duration))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)

                Text("\(entry.candidateCount)候補")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Text(entry.createdAt, style: .date)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            + Text(" ")
            + Text(entry.createdAt, style: .time)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            PipelineDebugLogger.shared.deleteEntry(at: entries[index].fileURL)
        }
        entries.remove(atOffsets: offsets)
    }
}
