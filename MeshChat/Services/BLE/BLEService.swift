import Foundation
import CoreBluetooth
import Combine

/// Coordinates Central + Peripheral managers and routes messages through the mesh.
@Observable
final class BLEService {
    // MARK: - State
    var isRunning = false
    var connectedPeerCount = 0
    var subscriberCount = 0
    var totalMessagesSent = 0
    var totalMessagesReceived = 0
    var totalMessagesRelayed = 0
    var peers: [Peer] = []

    // MARK: - Dependencies
    private let centralManager: BLECentralManager
    private let peripheralManager: BLEPeripheralManager
    private let fragmentAssembler = FragmentAssembler()
    private let deduplicator = MessageDeduplicator()
    private let router: MeshRouter

    var onMessageReceived: ((MeshMessage) -> Void)?

    init(router: MeshRouter) {
        self.router = router
        self.centralManager = BLECentralManager()
        self.peripheralManager = BLEPeripheralManager()
        self.centralManager.delegate = self
        self.peripheralManager.delegate = self
    }

    // MARK: - Control

    func start() {
        guard !isRunning else { return }
        centralManager.startScanning()
        peripheralManager.startAdvertising()
        isRunning = true
        MeshLogger.ble.info("BLE Service started")
    }

    func stop() {
        centralManager.stopScanning()
        peripheralManager.stopAdvertising()
        isRunning = false
        MeshLogger.ble.info("BLE Service stopped")
    }

    // MARK: - Send Message

    func sendMessage(_ message: MeshMessage) {
        do {
            let payloadData = try message.toPayloadData()
            let packet = BinaryPacket.createMessage(payload: payloadData)
            let encoded = packet.encode()

            // Check if fragmentation is needed
            if encoded.count > MeshConfig.fragmentSize + MeshConfig.headerSize {
                sendFragmented(payloadData, ttl: MeshConfig.defaultTTL)
            } else {
                broadcast(encoded)
            }

            deduplicator.markSeen(message.id)
            totalMessagesSent += 1
            MeshLogger.ble.info("Sent message: \(message.id)")
        } catch {
            MeshLogger.ble.error("Failed to encode message: \(error.localizedDescription)")
        }
    }

    private func sendFragmented(_ payload: Data, ttl: UInt8) {
        let fragments = fragmentAssembler.fragment(data: payload)
        for fragment in fragments {
            let fragmentData = fragment.header.encode() + fragment.payload
            let packet = BinaryPacket.createFragment(payload: fragmentData, ttl: ttl)
            broadcast(packet.encode())
        }
    }

    private func broadcast(_ data: Data) {
        // Send via Central (write to connected peripherals)
        centralManager.sendDataToAll(data)
        // Send via Peripheral (notify subscribers)
        peripheralManager.sendToSubscribers(data)
    }

    // MARK: - Receive & Relay

    private func handleReceivedData(_ data: Data) {
        MeshLogger.ble.info("handleReceivedData: \(data.count) bytes")
        guard let packet = BinaryPacket.decode(from: data) else {
            let hex = data.prefix(20).map { String(format: "%02x", $0) }.joined(separator: " ")
            MeshLogger.ble.warning("Failed to decode packet (\(data.count) bytes, hex: \(hex))")
            return
        }

        switch packet.type {
        case .message:
            handleMessagePacket(packet)
        case .fragment:
            handleFragmentPacket(packet)
        case .ack, .peerDiscovery, .heartbeat:
            break // Not implemented in MVP
        }
    }

    private func handleMessagePacket(_ packet: BinaryPacket) {
        do {
            let jsonStr = String(data: packet.payload, encoding: .utf8) ?? "nil"
            MeshLogger.ble.info("Raw payload (\(packet.payload.count) bytes): \(jsonStr.prefix(200))")

            var message = try MeshMessage.fromPayloadData(packet.payload)
            message.hopCount += 1

            guard !deduplicator.checkAndMark(message.id) else {
                MeshLogger.ble.debug("Duplicate message dropped: \(message.id)")
                return
            }

            totalMessagesReceived += 1
            onMessageReceived?(message)
            MeshLogger.ble.info("Received & decoded message: \(message.id) from \(message.senderName)")

            // Relay if allowed
            if router.shouldRelay(message: message) {
                relay(packet: packet, messageID: message.id)
            }
        } catch {
            MeshLogger.ble.error("Failed to decode message payload: \(error.localizedDescription)")
        }
    }

    private func handleFragmentPacket(_ packet: BinaryPacket) {
        guard packet.payload.count >= 4 else { return }

        guard let header = FragmentAssembler.FragmentHeader.decode(from: packet.payload) else { return }
        let fragmentPayload = packet.payload.subdata(in: 4..<packet.payload.count)

        if let assembled = fragmentAssembler.addFragment(header: header, payload: fragmentPayload) {
            // Reconstruct as a full message packet
            let fullPacket = BinaryPacket.createMessage(payload: assembled, ttl: packet.ttl)
            handleMessagePacket(fullPacket)
        }
    }

    private func relay(packet: BinaryPacket, messageID: String) {
        guard let relayPacket = packet.decrementedTTL() else {
            MeshLogger.ble.debug("TTL exhausted, not relaying: \(messageID)")
            return
        }
        broadcast(relayPacket.encode())
        totalMessagesRelayed += 1
        MeshLogger.ble.info("Relayed message: \(messageID)")
    }

    private func updatePeerList() {
        peers = Array(centralManager.peers.values).sorted { $0.lastSeen > $1.lastSeen }
        connectedPeerCount = centralManager.connectedCount
        subscriberCount = peripheralManager.subscriberCount
    }
}

// MARK: - BLECentralManagerDelegate
extension BLEService: BLECentralManagerDelegate {
    func centralManager(didReceiveData data: Data, from peripheral: CBPeripheral) {
        handleReceivedData(data)
    }

    func centralManager(didDiscoverPeer peer: Peer) {
        updatePeerList()
    }

    func centralManager(didConnectPeer id: UUID) {
        updatePeerList()
    }

    func centralManager(didDisconnectPeer id: UUID) {
        updatePeerList()
    }
}

// MARK: - BLEPeripheralManagerDelegate
extension BLEService: BLEPeripheralManagerDelegate {
    func peripheralManager(didReceiveData data: Data, from central: CBCentral) {
        handleReceivedData(data)
    }
}
