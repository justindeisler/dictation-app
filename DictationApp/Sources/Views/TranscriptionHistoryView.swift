import SwiftUI

struct TranscriptionHistoryView: View {
    @State private var transcriptions: [RecentTranscription] = []
    @State private var searchText = ""
    @State private var copiedId: UUID?

    private var filtered: [RecentTranscription] {
        if searchText.isEmpty { return transcriptions }
        return transcriptions.filter {
            $0.text.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search transcriptions...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Content
            if filtered.isEmpty {
                Spacer()
                if transcriptions.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No transcriptions yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Your transcriptions will appear here")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("No matching transcriptions")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(filtered) { item in
                        TranscriptionRow(
                            item: item,
                            isCopied: copiedId == item.id,
                            onCopy: { copyToClipboard(item) },
                            onDelete: { deleteItem(item) }
                        )
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Bottom toolbar
            HStack {
                Text("\(transcriptions.count) transcription\(transcriptions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Clear All") {
                    clearAll()
                }
                .disabled(transcriptions.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 500, height: 400)
        .onAppear {
            loadTranscriptions()
        }
    }

    private func loadTranscriptions() {
        transcriptions = RecentTranscriptionsManager.shared.getRecent()
    }

    private func copyToClipboard(_ item: RecentTranscription) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)

        // Visual confirmation
        copiedId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedId == item.id {
                copiedId = nil
            }
        }
    }

    private func deleteItem(_ item: RecentTranscription) {
        RecentTranscriptionsManager.shared.delete(id: item.id)
        loadTranscriptions()
    }

    private func clearAll() {
        RecentTranscriptionsManager.shared.clear()
        loadTranscriptions()
    }
}

// MARK: - Row View

private struct TranscriptionRow: View {
    let item: RecentTranscription
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .lineLimit(2)
                    .font(.body)

                Text(relativeTimestamp(item.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isCopied {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onCopy()
        }
        .contextMenu {
            Button("Copy") { onCopy() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private func relativeTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    TranscriptionHistoryView()
}
