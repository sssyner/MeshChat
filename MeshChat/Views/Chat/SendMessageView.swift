import SwiftUI

// Kept as placeholder — message input is now inline in MeshMapView
struct SendMessageView: View {
    let viewModel: ChatViewModel

    @State private var messageText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("メッセージ") {
                    TextEditor(text: $messageText)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("新規メッセージ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("送信") {
                        viewModel.sendMessage(text: messageText)
                        dismiss()
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
