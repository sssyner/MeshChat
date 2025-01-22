import Foundation

@Observable
final class StatsViewModel {
    var totalMessages = 0
    var unsyncedCount = 0
    var expiredDeleted = 0
    var logContents = ""

    private let messageStore: MessageStore
    private let bleService: BLEService
    private let cloudSync: CloudSyncService

    init(messageStore: MessageStore, bleService: BLEService, cloudSync: CloudSyncService) {
        self.messageStore = messageStore
        self.bleService = bleService
        self.cloudSync = cloudSync
    }

    func refresh() {
        do {
            totalMessages = try messageStore.allMessages().count
            unsyncedCount = try messageStore.unsyncedMessages().count
        } catch {
            MeshLogger.general.error("Stats refresh error: \(error.localizedDescription)")
        }
        logContents = MeshLogger.readLogFile()
    }

    func cleanExpired() {
        do {
            expiredDeleted = try messageStore.deleteExpiredMessages()
        } catch {
            MeshLogger.general.error("Clean expired error: \(error.localizedDescription)")
        }
    }

    func clearLogs() {
        MeshLogger.clearLogFile()
        logContents = ""
    }
}
