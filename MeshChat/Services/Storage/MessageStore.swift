import Foundation
import GRDB

final class MessageStore {
    private let dbQueue: DatabaseQueue

    init() throws {
        let databaseURL = try FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("meshchat_v2.sqlite")

        dbQueue = try DatabaseQueue(path: databaseURL.path)
        try migrate()
        MeshLogger.storage.info("Database opened at \(databaseURL.path)")
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "mesh_messages") { t in
                t.column("id", .text).primaryKey()
                t.column("senderID", .text).notNull()
                t.column("senderName", .text).notNull()
                t.column("senderPhotoURL", .text)
                t.column("message", .text).notNull()
                t.column("dangerType", .text)
                t.column("latitude", .double).notNull()
                t.column("longitude", .double).notNull()
                t.column("createdAt", .text).notNull()
                t.column("expiresAt", .text).notNull()
                t.column("hopCount", .integer).defaults(to: 0)
                t.column("maxHops", .integer).defaults(to: 7)
                t.column("signature", .text).notNull()
                t.column("isSynced", .boolean).defaults(to: false)
                t.column("receivedAt", .text).notNull()
            }

            try db.create(table: "seen_message_ids") { t in
                t.column("messageID", .text).primaryKey()
                t.column("seenAt", .text).notNull()
            }
        }

        migrator.registerMigration("v2") { db in
            if try !db.columns(in: "mesh_messages").contains(where: { $0.name == "senderPhotoURL" }) {
                try db.alter(table: "mesh_messages") { t in
                    t.add(column: "senderPhotoURL", .text)
                }
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - CRUD

    func insert(_ message: MeshMessage) throws {
        try dbQueue.write { db in
            try message.insert(db, onConflict: .ignore)
        }
        MeshLogger.storage.debug("Inserted message: \(message.id)")
    }

    func allMessages() throws -> [MeshMessage] {
        try dbQueue.read { db in
            try MeshMessage
                .order(MeshMessage.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    func unexpiredMessages() throws -> [MeshMessage] {
        let now = Date()
        return try dbQueue.read { db in
            try MeshMessage
                .filter(MeshMessage.Columns.expiresAt > now)
                .order(MeshMessage.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    func unsyncedMessages() throws -> [MeshMessage] {
        try dbQueue.read { db in
            try MeshMessage
                .filter(MeshMessage.Columns.isSynced == false)
                .fetchAll(db)
        }
    }

    func markAsSynced(_ ids: [String]) throws {
        try dbQueue.write { db in
            try MeshMessage
                .filter(ids.contains(MeshMessage.Columns.id))
                .updateAll(db, MeshMessage.Columns.isSynced.set(to: true))
        }
    }

    func messageExists(id: String) throws -> Bool {
        try dbQueue.read { db in
            try MeshMessage.fetchOne(db, key: id) != nil
        }
    }

    func deleteExpiredMessages() throws -> Int {
        try dbQueue.write { db in
            try MeshMessage
                .filter(MeshMessage.Columns.expiresAt < Date())
                .deleteAll(db)
        }
    }

    // MARK: - Seen Messages

    func markMessageSeen(_ messageID: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT OR IGNORE INTO seen_message_ids (messageID, seenAt) VALUES (?, ?)",
                arguments: [messageID, ISO8601DateFormatter().string(from: Date())]
            )
        }
    }

    func isMessageSeen(_ messageID: String) throws -> Bool {
        try dbQueue.read { db in
            try Row.fetchOne(
                db,
                sql: "SELECT 1 FROM seen_message_ids WHERE messageID = ?",
                arguments: [messageID]
            ) != nil
        }
    }

    // MARK: - Nearby Query

    func messagesNear(latitude: Double, longitude: Double, radiusDegrees: Double = 0.1) throws -> [MeshMessage] {
        try dbQueue.read { db in
            try MeshMessage
                .filter(
                    MeshMessage.Columns.latitude >= latitude - radiusDegrees &&
                    MeshMessage.Columns.latitude <= latitude + radiusDegrees &&
                    MeshMessage.Columns.longitude >= longitude - radiusDegrees &&
                    MeshMessage.Columns.longitude <= longitude + radiusDegrees
                )
                .filter(MeshMessage.Columns.expiresAt > Date())
                .order(MeshMessage.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }
}
