import Foundation

enum PacketType: UInt8, Codable {
    case message = 0x01
    case ack = 0x02
    case peerDiscovery = 0x03
    case fragment = 0x04
    case heartbeat = 0x05

    var description: String {
        switch self {
        case .message: return "MESSAGE"
        case .ack: return "ACK"
        case .peerDiscovery: return "PEER_DISCOVERY"
        case .fragment: return "FRAGMENT"
        case .heartbeat: return "HEARTBEAT"
        }
    }
}
