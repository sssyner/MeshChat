import Foundation
import GRDB

struct MeshMessage: Codable, Identifiable, Equatable {
    var id: String
    var senderID: String
    var senderName: String
    var senderPhotoURL: String?
    var message: String
    var dangerType: DangerType?
    var latitude: Double
    var longitude: Double
    var createdAt: Date
    var expiresAt: Date
    var hopCount: Int
    var maxHops: Int
    var signature: String
    var isSynced: Bool
    var receivedAt: Date

    var isExpired: Bool {
        Date() > expiresAt
    }

    static func create(
        senderID: String,
        senderName: String,
        message: String,
        dangerType: DangerType?,
        latitude: Double,
        longitude: Double
    ) -> MeshMessage {
        let now = Date()
        let id = UUID().uuidString
        let signature = MessageSignature.sign(
            id: id,
            senderID: senderID,
            message: message,
            timestamp: now
        )
        return MeshMessage(
            id: id,
            senderID: senderID,
            senderName: senderName,
            message: message,
            dangerType: dangerType,
            latitude: latitude,
            longitude: longitude,
            createdAt: now,
            expiresAt: now.addingTimeInterval(MeshConfig.messageTTLSeconds),
            hopCount: 0,
            maxHops: MeshConfig.maxHops,
            signature: signature,
            isSynced: false,
            receivedAt: now
        )
    }
}

// MARK: - GRDB
extension MeshMessage: FetchableRecord, PersistableRecord {
    static let databaseTableName = "mesh_messages"

    enum Columns: String, ColumnExpression {
        case id, senderID, senderName, senderPhotoURL, message, dangerType
        case latitude, longitude, createdAt, expiresAt
        case hopCount, maxHops, signature, isSynced, receivedAt
    }
}

// MARK: - Compact JSON for BLE payload
extension MeshMessage {
    struct CompactPayload: Codable {
        let id: String
        let sid: String  // senderID
        let sn: String   // senderName
        let msg: String
        let dt: String?   // dangerType
        let lat: Double
        let lon: Double
        let ts: Double    // createdAt timestamp
        let exp: Double   // expiresAt timestamp
        let hc: Int       // hopCount
        let mh: Int       // maxHops
        let sig: String
    }

    func toCompactPayload() -> CompactPayload {
        CompactPayload(
            id: id,
            sid: senderID,
            sn: senderName,
            msg: message,
            dt: dangerType?.rawValue,
            lat: latitude,
            lon: longitude,
            ts: createdAt.timeIntervalSince1970,
            exp: expiresAt.timeIntervalSince1970,
            hc: hopCount,
            mh: maxHops,
            sig: signature
        )
    }

    // Convert timestamp that may be in seconds or milliseconds
    private static func normalizeTimestamp(_ value: Double) -> Date {
        // If value > year 2100 in seconds (~4102444800), it's probably millis
        if value > 4_102_444_800 {
            return Date(timeIntervalSince1970: value / 1000.0)
        }
        return Date(timeIntervalSince1970: value)
    }

    static func fromCompactPayload(_ payload: CompactPayload) -> MeshMessage {
        MeshMessage(
            id: payload.id,
            senderID: payload.sid,
            senderName: payload.sn,
            message: payload.msg,
            dangerType: payload.dt.flatMap { DangerType(rawValue: $0) },
            latitude: payload.lat,
            longitude: payload.lon,
            createdAt: normalizeTimestamp(payload.ts),
            expiresAt: normalizeTimestamp(payload.exp),
            hopCount: payload.hc,
            maxHops: payload.mh,
            signature: payload.sig,
            isSynced: false,
            receivedAt: Date()
        )
    }

    func toPayloadData() throws -> Data {
        try JSONEncoder().encode(toCompactPayload())
    }

    static func fromPayloadData(_ data: Data) throws -> MeshMessage {
        let payload = try JSONDecoder().decode(CompactPayload.self, from: data)
        return fromCompactPayload(payload)
    }
}
