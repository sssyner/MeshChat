import Foundation
import FirebaseFirestore

@Observable
final class ModerationService {
    var blockedUserIDs: Set<String> = []

    private var _db: Firestore?
    private var db: Firestore {
        if _db == nil { _db = Firestore.firestore() }
        return _db!
    }

    init() {
        loadBlockedUsers()
    }

    func isBlocked(_ senderID: String) -> Bool {
        blockedUserIDs.contains(senderID)
    }

    func blockUser(_ senderID: String) {
        blockedUserIDs.insert(senderID)
        saveBlockedUsers()
        MeshLogger.general.info("Blocked user: \(senderID)")
    }

    func unblockUser(_ senderID: String) {
        blockedUserIDs.remove(senderID)
        saveBlockedUsers()
        MeshLogger.general.info("Unblocked user: \(senderID)")
    }

    func reportMessage(_ message: MeshMessage, reason: String, reporterID: String) async {
        do {
            let data: [String: Any] = [
                "messageId": message.id,
                "senderID": message.senderID,
                "senderName": message.senderName,
                "reason": reason,
                "reporterID": reporterID,
                "reportedAt": Timestamp(date: Date())
            ]
            try await db.collection("reports").addDocument(data: data)
            MeshLogger.general.info("Reported message: \(message.id)")
        } catch {
            MeshLogger.general.error("Report failed: \(error.localizedDescription)")
        }
    }

    private func loadBlockedUsers() {
        let array = UserDefaults.standard.stringArray(forKey: "meshchat_blocked_users") ?? []
        blockedUserIDs = Set(array)
    }

    private func saveBlockedUsers() {
        UserDefaults.standard.set(Array(blockedUserIDs), forKey: "meshchat_blocked_users")
    }
}
