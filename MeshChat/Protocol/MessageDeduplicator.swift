import Foundation

/// LRU cache for message deduplication.
/// Prevents relaying already-seen messages.
final class MessageDeduplicator {

    private struct Entry {
        let messageID: String
        let timestamp: Date
    }

    private var cache: [String: Date] = [:]
    private var order: [String] = []
    private let maxSize: Int
    private let ttl: TimeInterval
    private let lock = NSLock()

    init(maxSize: Int = MeshConfig.deduplicationCacheSize,
         ttl: TimeInterval = MeshConfig.deduplicationTTL) {
        self.maxSize = maxSize
        self.ttl = ttl
    }

    /// Returns true if the message has already been seen (duplicate)
    func isDuplicate(_ messageID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        cleanExpired()

        if let seenAt = cache[messageID] {
            if Date().timeIntervalSince(seenAt) < ttl {
                return true
            }
            // Expired entry, remove and re-add
            removeFromOrder(messageID)
            cache.removeValue(forKey: messageID)
        }
        return false
    }

    /// Mark a message as seen
    func markSeen(_ messageID: String) {
        lock.lock()
        defer { lock.unlock() }

        if cache[messageID] != nil {
            removeFromOrder(messageID)
        }

        cache[messageID] = Date()
        order.append(messageID)

        // Evict LRU if over capacity
        while order.count > maxSize {
            let oldest = order.removeFirst()
            cache.removeValue(forKey: oldest)
        }
    }

    /// Check and mark in one operation. Returns true if duplicate.
    func checkAndMark(_ messageID: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        cleanExpired()

        if let seenAt = cache[messageID], Date().timeIntervalSince(seenAt) < ttl {
            return true
        }

        // Remove old entry if exists
        if cache[messageID] != nil {
            removeFromOrder(messageID)
        }

        cache[messageID] = Date()
        order.append(messageID)

        while order.count > maxSize {
            let oldest = order.removeFirst()
            cache.removeValue(forKey: oldest)
        }

        return false
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }

    private func cleanExpired() {
        let now = Date()
        while let first = order.first, let ts = cache[first], now.timeIntervalSince(ts) > ttl {
            order.removeFirst()
            cache.removeValue(forKey: first)
        }
    }

    private func removeFromOrder(_ id: String) {
        if let idx = order.firstIndex(of: id) {
            order.remove(at: idx)
        }
    }
}
