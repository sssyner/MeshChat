import Foundation
import CoreBluetooth

struct Peer: Identifiable, Equatable {
    let id: UUID // CBPeripheral identifier
    var name: String?
    var rssi: Int
    var peripheral: CBPeripheral?
    var isConnected: Bool
    var lastSeen: Date
    var messagesRelayed: Int

    static func == (lhs: Peer, rhs: Peer) -> Bool {
        lhs.id == rhs.id
    }
}
