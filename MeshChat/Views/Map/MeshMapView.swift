import SwiftUI
import MapKit

struct MeshMapView: View {
    let viewModel: MapViewModel
    let bleService: BLEService
    let chatViewModel: ChatViewModel
    let cloudSync: CloudSyncService

    @State private var selectedMessage: MeshMessage?
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.68, longitude: 139.70),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )
    @State private var mapMessages: [MeshMessage] = []
    @State private var messageText = ""
    @State private var selectedDangerType: DangerType?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var mapCenter = CLLocationCoordinate2D(latitude: 35.68, longitude: 139.70)
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mapContent

                // センターピン
                Image(systemName: "mappin")
                    .font(.system(size: 32))
                    .foregroundStyle(.red)
                    .shadow(radius: 2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -16)
                    .allowsHitTesting(false)

                composeBar
            }
            .navigationTitle("マップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleDisplayMode(.inline)
            .sheet(item: $selectedMessage) { msg in
                MessageDetailSheet(message: msg)
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            viewModel.loadMessages()
            mapMessages = viewModel.messages
        }
        .onChange(of: chatViewModel.messages.count) { _, _ in
            viewModel.loadMessages()
            mapMessages = viewModel.messages
        }
        .onChange(of: viewModel.messages.count) { _, _ in
            mapMessages = viewModel.messages
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 8) {
                StatusBadge(icon: "message.fill", text: "\(mapMessages.count)", color: .blue)
                StatusBadge(icon: "antenna.radiowaves.left.and.right", text: "\(bleService.connectedPeerCount)", color: .green)
            }
        }
    }

    private var composeBar: some View {
        HStack(spacing: 8) {
            TextField("メッセージを投稿...", text: $messageText)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(messageText.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                    .clipShape(Circle())
            }
            .disabled(messageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var mapContent: some View {
        Map(position: $cameraPosition) {
            ForEach(mapMessages) { msg in
                Annotation(msg.senderName, coordinate: CLLocationCoordinate2D(latitude: msg.latitude, longitude: msg.longitude)) {
                    MessagePin(message: msg)
                        .onTapGesture { selectedMessage = msg }
                }
            }
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            mapCenter = context.camera.centerCoordinate
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        chatViewModel.sendMessage(
            text: text,
            dangerType: selectedDangerType,
            latitude: mapCenter.latitude,
            longitude: mapCenter.longitude
        )

        if let err = chatViewModel.errorMessage {
            errorMessage = err
            showError = true
            return
        }

        messageText = ""
        selectedDangerType = nil
        isTextFieldFocused = false
        viewModel.loadMessages()
        mapMessages = viewModel.messages
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let icon: String
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption2.monospacedDigit())
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.ultraThinMaterial).foregroundStyle(color).clipShape(Capsule())
    }
}

// MARK: - Message Detail Sheet
struct MessageDetailSheet: View {
    let message: MeshMessage
    var onReport: ((MeshMessage) -> Void)?
    var onBlock: ((MeshMessage) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showReportSheet = false
    @State private var showBlockAlert = false
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(message.message).font(.body)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "送信者", value: message.senderName)
                    DetailRow(label: "時刻", value: message.createdAt.relativeString)
                    DetailRow(label: "ホップ", value: "\(message.hopCount) / \(message.maxHops)")
                    DetailRow(label: "位置", value: String(format: "%.4f, %.4f", message.latitude, message.longitude))
                    DetailRow(label: "同期", value: message.isSynced ? "済み" : "未")
                }
                Spacer()
            }
            .padding()
            .navigationTitle("メッセージ詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } }
            }
        }
    }
}

struct DetailRow: View {
    let label: String; let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
            Text(value)
        }.font(.subheadline)
    }
}

struct MessagePin: View {
    let message: MeshMessage
    var body: some View {
        VStack(spacing: 2) {
            Text(message.message).font(.caption2).lineLimit(3)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(.white).foregroundStyle(.black)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            Text(message.senderName).font(.system(size: 9)).foregroundStyle(.secondary)
        }.frame(maxWidth: 160)
    }
}
