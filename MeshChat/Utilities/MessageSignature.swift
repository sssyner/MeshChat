import Foundation
import CryptoKit

enum MessageSignature {
    static func sign(id: String, senderID: String, message: String, timestamp: Date) -> String {
        let payload = "\(id):\(senderID):\(message):\(Int(timestamp.timeIntervalSince1970))"
        let data = Data(payload.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    static func verify(message: MeshMessage) -> Bool {
        let expected = sign(
            id: message.id,
            senderID: message.senderID,
            message: message.message,
            timestamp: message.createdAt
        )
        return expected == message.signature
    }
}
