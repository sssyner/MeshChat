import SwiftUI

struct ChatListView: View {
    let viewModel: ChatViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.messages.isEmpty {
                    ContentUnavailableView(
                        "メッセージなし",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("近くのメッシュデバイスからのメッセージがここに表示されます")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.messages) { message in
                                MessageCardView(
                                    message: message,
                                    onReport: { viewModel.reportMessage($0) },
                                    onBlock: { viewModel.blockUser($0.senderID) }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("メッシュチャット")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refreshFromCloud() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                viewModel.loadMessages()
            }
            .refreshable {
                await viewModel.refreshFromCloud()
            }
        }
    }
}
