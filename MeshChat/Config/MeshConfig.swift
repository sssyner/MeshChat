import Foundation

enum MeshConfig {
    // MARK: - Protocol
    static let protocolVersion: UInt8 = 1
    static let headerSize = 14
    static let defaultTTL: UInt8 = 7
    static let maxHops: Int = 7
    static let messageTTLSeconds: TimeInterval = 24 * 60 * 60 // 24 hours

    // MARK: - BLE MTU & Fragmentation
    static let defaultMTU = 512
    static let attOverhead = 3
    static let fragmentHeaderSize = 4 // reassemblyID(2) + index(1) + total(1)
    static let maxFragmentPayload = defaultMTU - attOverhead - fragmentHeaderSize - headerSize // ~487 for raw, but we use 469 for safety
    static let fragmentSize = 469
    static let reassemblyTimeout: TimeInterval = 30
    static let maxConcurrentReassembly = 128

    // MARK: - BLE Connection
    static let maxCentralConnections = 7
    static let connectionTimeout: TimeInterval = 10
    static let reconnectCooldown: TimeInterval = 30
    static let rssiThreshold: Int = -80
    static let maintenanceInterval: TimeInterval = 5

    // MARK: - Scan Duty Cycle (foreground only)
    static let scanOnDuration: TimeInterval = 5
    static let scanOffDuration: TimeInterval = 10

    // MARK: - Deduplication
    static let deduplicationCacheSize = 1000
    static let deduplicationTTL: TimeInterval = 300 // 5 minutes

    // MARK: - Cloud Sync
    static let firestoreCollection = "mesh_disaster_messages"
    static let syncBatchSize = 50
}
