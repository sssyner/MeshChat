import Foundation
import FirebaseFirestore
import Network

@Observable
final class CloudSyncService {
    var isSyncing = false
    var isOnline = false
    var lastSyncTime: Date?
    var syncedCount = 0

    private var _db: Firestore?
    private var db: Firestore {
        if _db == nil { _db = Firestore.firestore() }
        return _db!
    }
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.meshchat.network")
    private var messageStore: MessageStore?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
                if path.status == .satisfied {
                    await self?.syncPendingMessages()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func configure(store: MessageStore) {
        self.messageStore = store
    }

    // MARK: - Upload unsynced messages

    func syncPendingMessages() async {
        guard let store = messageStore, !isSyncing, isOnline else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let unsynced = try store.unsyncedMessages()
            guard !unsynced.isEmpty else { return }

            let batch = db.batch()
            var syncedIDs: [String] = []

            for message in unsynced.prefix(MeshConfig.syncBatchSize) {
                let ref = db.collection(MeshConfig.firestoreCollection).document(message.id)
                let data: [String: Any] = [
                    "id": message.id,
                    "senderID": message.senderID,
                    "senderName": message.senderName,
                    "message": message.message,
                    "dangerType": message.dangerType?.rawValue ?? NSNull(),
                    "latitude": message.latitude,
                    "longitude": message.longitude,
                    "createdAt": Timestamp(date: message.createdAt),
                    "expiresAt": Timestamp(date: message.expiresAt),
                    "hopCount": message.hopCount,
                    "maxHops": message.maxHops,
                    "signature": message.signature
                ]
                batch.setData(data, forDocument: ref, merge: true)
                syncedIDs.append(message.id)
            }

            try await batch.commit()
            try store.markAsSynced(syncedIDs)
            syncedCount += syncedIDs.count
            lastSyncTime = Date()

            MeshLogger.sync.info("Synced \(syncedIDs.count) messages to Firestore")
        } catch {
            MeshLogger.sync.error("Sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Download messages

    /// 世界中の最新メッセージを取得（平時用）
    func fetchGlobalMessages(limit: Int = 200) async -> [MeshMessage] {
        guard isOnline else { return [] }

        do {
            let snapshot = try await db.collection(MeshConfig.firestoreCollection)
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()

            let messages = snapshot.documents.compactMap { doc in
                parseMessage(from: doc.data())
            }

            MeshLogger.sync.info("Fetched \(messages.count) global messages from Firestore")
            return messages
        } catch {
            MeshLogger.sync.error("Global fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    /// 近くのメッセージを取得（災害時・BLE補完用）
    func fetchNearbyMessages(latitude: Double, longitude: Double, radiusDegrees: Double = 0.1) async -> [MeshMessage] {
        guard isOnline else { return [] }

        do {
            let snapshot = try await db.collection(MeshConfig.firestoreCollection)
                .whereField("latitude", isGreaterThan: latitude - radiusDegrees)
                .whereField("latitude", isLessThan: latitude + radiusDegrees)
                .order(by: "latitude")
                .limit(to: 100)
                .getDocuments()

            let messages = snapshot.documents.compactMap { doc -> MeshMessage? in
                guard let msg = parseMessage(from: doc.data()) else { return nil }
                guard msg.longitude >= longitude - radiusDegrees &&
                      msg.longitude <= longitude + radiusDegrees else { return nil }
                return msg
            }

            MeshLogger.sync.info("Fetched \(messages.count) nearby messages from Firestore")
            return messages
        } catch {
            MeshLogger.sync.error("Fetch failed: \(error.localizedDescription)")
            return []
        }
    }

    private func parseMessage(from data: [String: Any]) -> MeshMessage? {
        guard let id = data["id"] as? String,
              let senderID = data["senderID"] as? String,
              let senderName = data["senderName"] as? String,
              let message = data["message"] as? String,
              let lat = data["latitude"] as? Double,
              let lon = data["longitude"] as? Double,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let expiresAt = (data["expiresAt"] as? Timestamp)?.dateValue(),
              let signature = data["signature"] as? String
        else { return nil }

        return MeshMessage(
            id: id,
            senderID: senderID,
            senderName: senderName,
            message: message,
            dangerType: (data["dangerType"] as? String).flatMap { DangerType(rawValue: $0) },
            latitude: lat,
            longitude: lon,
            createdAt: createdAt,
            expiresAt: expiresAt,
            hopCount: data["hopCount"] as? Int ?? 0,
            maxHops: data["maxHops"] as? Int ?? 7,
            signature: signature,
            isSynced: true,
            receivedAt: Date()
        )
    }

    deinit {
        monitor.cancel()
    }
}
