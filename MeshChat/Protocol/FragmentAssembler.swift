import Foundation

/// Handles fragmentation and reassembly of large messages over BLE.
/// Fragment header: [reassemblyID:2][index:1][total:1] = 4 bytes
final class FragmentAssembler {

    struct FragmentHeader {
        let reassemblyID: UInt16
        let index: UInt8
        let total: UInt8

        func encode() -> Data {
            var data = Data(capacity: 4)
            var rid = reassemblyID.bigEndian
            data.append(Data(bytes: &rid, count: 2))
            data.append(index)
            data.append(total)
            return data
        }

        static func decode(from data: Data) -> FragmentHeader? {
            guard data.count >= 4 else { return nil }
            let rid = data.subdata(in: 0..<2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            return FragmentHeader(reassemblyID: rid, index: data[2], total: data[3])
        }
    }

    private struct ReassemblySession {
        let total: Int
        var fragments: [UInt8: Data]
        let startedAt: Date

        var isComplete: Bool { fragments.count == total }

        var isExpired: Bool {
            Date().timeIntervalSince(startedAt) > MeshConfig.reassemblyTimeout
        }

        func assemble() -> Data? {
            guard isComplete else { return nil }
            var result = Data()
            for i in 0..<UInt8(total) {
                guard let fragment = fragments[i] else { return nil }
                result.append(fragment)
            }
            return result
        }
    }

    private var sessions: [UInt16: ReassemblySession] = [:]
    private var nextReassemblyID: UInt16 = 0
    private let lock = NSLock()

    // MARK: - Fragment (split outgoing data)

    func fragment(data: Data) -> [(header: FragmentHeader, payload: Data)] {
        let fragmentPayloadSize = MeshConfig.fragmentSize
        guard data.count > fragmentPayloadSize else {
            // No fragmentation needed
            return []
        }

        lock.lock()
        let rid = nextReassemblyID
        nextReassemblyID &+= 1
        lock.unlock()

        var fragments: [(header: FragmentHeader, payload: Data)] = []
        var offset = 0
        var index: UInt8 = 0
        let totalFragments = UInt8((data.count + fragmentPayloadSize - 1) / fragmentPayloadSize)

        while offset < data.count {
            let end = min(offset + fragmentPayloadSize, data.count)
            let chunk = data.subdata(in: offset..<end)
            let header = FragmentHeader(reassemblyID: rid, index: index, total: totalFragments)
            fragments.append((header: header, payload: chunk))
            offset = end
            index += 1
        }

        MeshLogger.mesh.debug("Fragmented \(data.count) bytes into \(fragments.count) fragments (rid=\(rid))")
        return fragments
    }

    // MARK: - Reassemble (collect incoming fragments)

    /// Returns assembled data when all fragments are received, nil otherwise
    func addFragment(header: FragmentHeader, payload: Data) -> Data? {
        lock.lock()
        defer { lock.unlock() }

        // Clean expired sessions
        cleanExpiredSessions()

        // Check capacity
        if sessions.count >= MeshConfig.maxConcurrentReassembly && sessions[header.reassemblyID] == nil {
            MeshLogger.mesh.warning("Max reassembly sessions reached, dropping fragment")
            return nil
        }

        if sessions[header.reassemblyID] == nil {
            sessions[header.reassemblyID] = ReassemblySession(
                total: Int(header.total),
                fragments: [:],
                startedAt: Date()
            )
        }

        sessions[header.reassemblyID]?.fragments[header.index] = payload

        guard let session = sessions[header.reassemblyID], session.isComplete else {
            return nil
        }

        let assembled = session.assemble()
        sessions.removeValue(forKey: header.reassemblyID)

        if let assembled {
            MeshLogger.mesh.debug("Reassembled \(assembled.count) bytes (rid=\(header.reassemblyID))")
        }

        return assembled
    }

    private func cleanExpiredSessions() {
        let expired = sessions.filter { $0.value.isExpired }
        for (key, _) in expired {
            MeshLogger.mesh.debug("Reassembly session expired: rid=\(key)")
            sessions.removeValue(forKey: key)
        }
    }

    var activeSessionCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return sessions.count
    }
}
