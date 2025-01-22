import SwiftUI

struct StatsView: View {
    let viewModel: StatsViewModel
    let bleService: BLEService
    let cloudSync: CloudSyncService

    var body: some View {
        NavigationStack {
            List {
                Section("通信状態") {
                    StatRow(label: "メッシュ通信", value: bleService.isRunning ? "オン" : "オフ")
                    StatRow(label: "近くの端末", value: "\(bleService.connectedPeerCount)台")
                    StatRow(label: "送ったメッセージ", value: "\(bleService.totalMessagesSent)件")
                    StatRow(label: "届いたメッセージ", value: "\(bleService.totalMessagesReceived)件")
                    StatRow(label: "中継したメッセージ", value: "\(bleService.totalMessagesRelayed)件")
                }

                Section("近くの端末") {
                    if bleService.peers.isEmpty {
                        Text("周囲にMeshChatユーザーがいません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(bleService.peers) { peer in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(peer.name ?? "端末 \(peer.id.uuidString.prefix(4))")
                                        .font(.subheadline)
                                    Text(signalStrengthText(peer.rssi))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Circle()
                                    .fill(peer.isConnected ? .green : .gray)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }

                Section("インターネット") {
                    StatRow(label: "接続", value: cloudSync.isOnline ? "オンライン" : "オフライン")
                    StatRow(label: "同期済み", value: "\(cloudSync.syncedCount)件")
                    StatRow(label: "未送信", value: "\(viewModel.unsyncedCount)件")
                    if let lastSync = cloudSync.lastSyncTime {
                        StatRow(label: "最終同期", value: lastSync.relativeString)
                    }
                }

                Section("メッセージ管理") {
                    StatRow(label: "保存メッセージ数", value: "\(viewModel.totalMessages)件")
                    Button("古いメッセージを削除") {
                        viewModel.cleanExpired()
                        viewModel.refresh()
                    }
                    if viewModel.expiredDeleted > 0 {
                        Text("\(viewModel.expiredDeleted)件の古いメッセージを削除しました")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("ステータス")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                viewModel.refresh()
            }
        }
    }
}

private func signalStrengthText(_ rssi: Int) -> String {
    switch rssi {
    case -50...0: return "電波: 強い"
    case -70...(-51): return "電波: 普通"
    case -85...(-71): return "電波: 弱い"
    default: return "電波: とても弱い"
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
