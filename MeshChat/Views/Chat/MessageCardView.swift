import SwiftUI

struct MessageCardView: View {
    let message: MeshMessage
    var onReport: ((MeshMessage) -> Void)?
    var onBlock: ((MeshMessage) -> Void)?

    @State private var showReportSheet = false
    @State private var showBlockAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                if let dangerType = message.dangerType {
                    Label(dangerType.displayName, systemImage: dangerType.icon)
                        .font(.caption.bold())
                        .foregroundStyle(dangerType.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(dangerType.color.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer()

                Text(message.createdAt.relativeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Message body
            Text(message.message)
                .font(.body)

            // Footer
            HStack(spacing: 12) {
                Label(message.senderName, systemImage: "person.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Label("\(message.hopCount) ホップ", systemImage: "arrow.triangle.branch")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if message.isSynced {
                    Image(systemName: "cloud.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .contextMenu {
            Button {
                showReportSheet = true
            } label: {
                Label("通報する", systemImage: "exclamationmark.triangle")
            }
            Button(role: .destructive) {
                showBlockAlert = true
            } label: {
                Label("このユーザーをブロック", systemImage: "hand.raised")
            }
        }
        .confirmationDialog("通報理由を選択", isPresented: $showReportSheet, titleVisibility: .visible) {
            Button("スパム") { onReport?(message) }
            Button("虚偽の災害情報") { onReport?(message) }
            Button("嫌がらせ・誹謗中傷") { onReport?(message) }
            Button("不適切なコンテンツ") { onReport?(message) }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("ユーザーをブロック", isPresented: $showBlockAlert) {
            Button("ブロック", role: .destructive) { onBlock?(message) }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("\(message.senderName) をブロックしますか？このユーザーのメッセージは表示されなくなります。")
        }
    }
}
