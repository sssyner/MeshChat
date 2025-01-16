import Foundation

/// Determines whether a received message should be relayed to other peers.
final class MeshRouter {

    /// Decides if a message should be relayed (simple flooding with TTL)
    func shouldRelay(message: MeshMessage) -> Bool {
        // Don't relay expired messages
        guard !message.isExpired else {
            MeshLogger.mesh.debug("Not relaying expired message: \(message.id)")
            return false
        }

        // Don't relay if max hops reached
        guard message.hopCount < message.maxHops else {
            MeshLogger.mesh.debug("Not relaying, max hops reached: \(message.id)")
            return false
        }

        return true
    }
}
