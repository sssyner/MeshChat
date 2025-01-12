import Foundation

/// 14-byte fixed header + variable payload
/// [Version:1][Type:1][TTL:1][Timestamp:8][Flags:1][PayloadLength:2]
struct BinaryPacket {
    var version: UInt8
    var type: PacketType
    var ttl: UInt8
    var timestamp: UInt64 // Unix timestamp in seconds
    var flags: UInt8
    var payload: Data

    // Flag bits
    static let flagFragmented: UInt8 = 0x01
    static let flagNeedsAck: UInt8 = 0x02

    var isFragmented: Bool {
        flags & Self.flagFragmented != 0
    }

    static func createMessage(payload: Data, ttl: UInt8 = MeshConfig.defaultTTL) -> BinaryPacket {
        BinaryPacket(
            version: MeshConfig.protocolVersion,
            type: .message,
            ttl: ttl,
            timestamp: UInt64(Date().timeIntervalSince1970),
            flags: 0,
            payload: payload
        )
    }

    static func createFragment(payload: Data, ttl: UInt8 = MeshConfig.defaultTTL) -> BinaryPacket {
        BinaryPacket(
            version: MeshConfig.protocolVersion,
            type: .fragment,
            ttl: ttl,
            timestamp: UInt64(Date().timeIntervalSince1970),
            flags: Self.flagFragmented,
            payload: payload
        )
    }

    // MARK: - Encode

    func encode() -> Data {
        var data = Data(capacity: MeshConfig.headerSize + payload.count)

        data.append(version)
        data.append(type.rawValue)
        data.append(ttl)

        var ts = timestamp.bigEndian
        data.append(Data(bytes: &ts, count: 8))

        data.append(flags)

        var len = UInt16(payload.count).bigEndian
        data.append(Data(bytes: &len, count: 2))

        data.append(payload)

        return data
    }

    // MARK: - Decode

    static func decode(from data: Data) -> BinaryPacket? {
        guard data.count >= MeshConfig.headerSize else {
            MeshLogger.mesh.error("Packet too small: \(data.count) bytes")
            return nil
        }

        let version = data[0]
        guard let type = PacketType(rawValue: data[1]) else {
            MeshLogger.mesh.error("Unknown packet type: \(data[1])")
            return nil
        }
        let ttl = data[2]

        let timestamp = data.subdata(in: 3..<11).withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        let flags = data[11]
        let payloadLength = data.subdata(in: 12..<14).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }

        let expectedTotal = MeshConfig.headerSize + Int(payloadLength)
        guard data.count >= expectedTotal else {
            MeshLogger.mesh.error("Packet truncated: expected \(expectedTotal), got \(data.count)")
            return nil
        }

        let payload = data.subdata(in: MeshConfig.headerSize..<expectedTotal)

        return BinaryPacket(
            version: version,
            type: type,
            ttl: ttl,
            timestamp: timestamp,
            flags: flags,
            payload: payload
        )
    }

    /// Decrement TTL for relay, returns nil if TTL exhausted
    func decrementedTTL() -> BinaryPacket? {
        guard ttl > 1 else { return nil }
        var copy = self
        copy.ttl = ttl - 1
        return copy
    }
}
