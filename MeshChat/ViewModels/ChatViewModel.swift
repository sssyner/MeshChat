import Foundation

@Observable
final class ChatViewModel {
    var messages: [MeshMessage] = []
    var isLoading = false
    var errorMessage: String?

    private let messageStore: MessageStore
    private let bleService: BLEService
    private let authService: AuthService
    private let locationService: LocationService
    private let cloudSync: CloudSyncService
    private let moderationService: ModerationService

    init(messageStore: MessageStore, bleService: BLEService, authService: AuthService,
         locationService: LocationService, cloudSync: CloudSyncService, moderationService: ModerationService) {
        self.messageStore = messageStore
        self.bleService = bleService
        self.authService = authService
        self.locationService = locationService
        self.cloudSync = cloudSync
        self.moderationService = moderationService

        // Listen for incoming BLE messages
        bleService.onMessageReceived = { [weak self] message in
            Task { @MainActor in
                self?.handleReceivedMessage(message)
            }
        }
    }

    func loadMessages() {
        do {
            let allMessages = try messageStore.unexpiredMessages()
            messages = allMessages.filter { !moderationService.isBlocked($0.senderID) }
        } catch {
            errorMessage = error.localizedDescription
            MeshLogger.general.error("Failed to load messages: \(error.localizedDescription)")
        }
    }

    func sendMessage(text: String, dangerType: DangerType? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        guard let userID = authService.currentUserID else {
            errorMessage = "ログインしていません"
            return
        }

        let message = MeshMessage.create(
            senderID: userID,
            senderName: authService.displayName,
            message: text,
            dangerType: dangerType,
            latitude: latitude ?? locationService.latitude,
            longitude: longitude ?? locationService.longitude
        )

        do {
            try messageStore.insert(message)
            bleService.sendMessage(message)
            messages.insert(message, at: 0)

            // Trigger cloud sync
            Task {
                await cloudSync.syncPendingMessages()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshFromCloud() async {
        guard locationService.hasLocation else { return }

        let cloudMessages = await cloudSync.fetchNearbyMessages(
            latitude: locationService.latitude,
            longitude: locationService.longitude
        )

        for msg in cloudMessages {
            do {
                if !(try messageStore.messageExists(id: msg.id)) {
                    try messageStore.insert(msg)
                }
            } catch {
                MeshLogger.general.error("Failed to store cloud message: \(error.localizedDescription)")
            }
        }

        loadMessages()
    }

    func reportMessage(_ message: MeshMessage) {
        guard let reporterID = authService.currentUserID else { return }
        Task {
            await moderationService.reportMessage(message, reason: "User report", reporterID: reporterID)
        }
    }

    func blockUser(_ senderID: String) {
        moderationService.blockUser(senderID)
        loadMessages()
    }

    private func handleReceivedMessage(_ message: MeshMessage) {
        guard !moderationService.isBlocked(message.senderID) else { return }
        do {
            try messageStore.insert(message)
            if !messages.contains(where: { $0.id == message.id }) {
                messages.insert(message, at: 0)
            }
        } catch {
            MeshLogger.general.error("Failed to store received message: \(error.localizedDescription)")
        }
    }
}
