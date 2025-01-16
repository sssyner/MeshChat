import Foundation
import CoreBluetooth
import os

protocol BLECentralManagerDelegate: AnyObject {
    func centralManager(didReceiveData data: Data, from peripheral: CBPeripheral)
    func centralManager(didDiscoverPeer peer: Peer)
    func centralManager(didConnectPeer id: UUID)
    func centralManager(didDisconnectPeer id: UUID)
}

final class BLECentralManager: NSObject {
    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var connectedPeripherals: [UUID: CBPeripheral] = [:]
    private var peripheralCharacteristics: [UUID: CBCharacteristic] = [:]
    private var disconnectTimestamps: [UUID: Date] = [:]
    private var scanTimer: Timer?
    private var maintenanceTimer: Timer?
    private var isScanning = false

    weak var delegate: BLECentralManagerDelegate?

    private(set) var peers: [UUID: Peer] = [:]

    override init() {
        super.init()
        centralManager = CBCentralManager(
            delegate: self,
            queue: DispatchQueue(label: "com.meshchat.central", qos: .userInitiated),
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: BLEConstants.centralRestorationID,
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
        )
    }

    // MARK: - Scanning

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        startDutyCycleScan()
        startMaintenanceTimer()
        MeshLogger.ble.info("Central scanning started")
    }

    func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
        maintenanceTimer?.invalidate()
        maintenanceTimer = nil
        if isScanning {
            centralManager.stopScan()
            isScanning = false
        }
        MeshLogger.ble.info("Central scanning stopped")
    }

    private func startDutyCycleScan() {
        performScan()

        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: MeshConfig.scanOnDuration + MeshConfig.scanOffDuration, repeats: true) { [weak self] _ in
            self?.performScan()
        }
    }

    private func performScan() {
        guard centralManager.state == .poweredOn else { return }

        centralManager.scanForPeripherals(
            withServices: [BLEConstants.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true

        DispatchQueue.main.asyncAfter(deadline: .now() + MeshConfig.scanOnDuration) { [weak self] in
            guard let self, self.isScanning else { return }
            self.centralManager.stopScan()
            self.isScanning = false
        }
    }

    // MARK: - Connection

    func connectToPeripheral(_ peripheral: CBPeripheral) {
        guard connectedPeripherals.count < MeshConfig.maxCentralConnections else {
            MeshLogger.ble.warning("Max connections reached (\(MeshConfig.maxCentralConnections))")
            return
        }

        // Check reconnect cooldown
        if let lastDisconnect = disconnectTimestamps[peripheral.identifier],
           Date().timeIntervalSince(lastDisconnect) < MeshConfig.reconnectCooldown {
            MeshLogger.ble.debug("Reconnect cooldown active for \(peripheral.identifier)")
            return
        }

        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
        discoveredPeripherals[peripheral.identifier] = peripheral

        // Connection timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + MeshConfig.connectionTimeout) { [weak self] in
            guard let self else { return }
            if peripheral.state != .connected {
                self.centralManager.cancelPeripheralConnection(peripheral)
                MeshLogger.ble.warning("Connection timeout: \(peripheral.identifier)")
            }
        }
    }

    func sendData(_ data: Data, to peripheralID: UUID) {
        guard let peripheral = connectedPeripherals[peripheralID],
              let characteristic = peripheralCharacteristics[peripheralID] else {
            MeshLogger.ble.warning("Cannot send: no connection to \(peripheralID)")
            return
        }

        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse)
            ? .withoutResponse : .withResponse

        peripheral.writeValue(data, for: characteristic, type: writeType)
        MeshLogger.ble.debug("Sent \(data.count) bytes to \(peripheralID)")
    }

    func sendDataToAll(_ data: Data) {
        for (id, _) in connectedPeripherals {
            sendData(data, to: id)
        }
    }

    var connectedCount: Int { connectedPeripherals.count }

    // MARK: - Maintenance

    private func startMaintenanceTimer() {
        maintenanceTimer?.invalidate()
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: MeshConfig.maintenanceInterval, repeats: true) { [weak self] _ in
            self?.performMaintenance()
        }
    }

    private func performMaintenance() {
        let now = Date()
        var staleIDs: [UUID] = []

        for (id, peer) in peers {
            if now.timeIntervalSince(peer.lastSeen) > 60 {
                staleIDs.append(id)
            }
        }

        for id in staleIDs {
            if let peripheral = connectedPeripherals[id] {
                centralManager.cancelPeripheralConnection(peripheral)
            }
            peers.removeValue(forKey: id)
            MeshLogger.ble.debug("Removed stale peer: \(id)")
        }
    }

    // MARK: - State Restoration

    func restoreState(from dict: [String: Any]) {
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                peripheral.delegate = self
                discoveredPeripherals[peripheral.identifier] = peripheral
                if peripheral.state == .connected {
                    connectedPeripherals[peripheral.identifier] = peripheral
                    MeshLogger.ble.info("Restored connected peripheral: \(peripheral.identifier)")
                }
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLECentralManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MeshLogger.ble.info("Central state: \(central.state.rawValue)")
        if central.state == .poweredOn {
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        MeshLogger.ble.info("Central willRestoreState")
        restoreState(from: dict)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let rssiValue = RSSI.intValue
        guard rssiValue >= MeshConfig.rssiThreshold, rssiValue != 127 else {
            return
        }

        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String

        let peer = Peer(
            id: peripheral.identifier,
            name: name,
            rssi: rssiValue,
            peripheral: peripheral,
            isConnected: false,
            lastSeen: Date(),
            messagesRelayed: 0
        )

        peers[peripheral.identifier] = peer
        delegate?.centralManager(didDiscoverPeer: peer)

        // Auto-connect if not already connected
        if connectedPeripherals[peripheral.identifier] == nil {
            connectToPeripheral(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedPeripherals[peripheral.identifier] = peripheral
        peers[peripheral.identifier]?.isConnected = true
        peripheral.discoverServices([BLEConstants.serviceUUID])
        delegate?.centralManager(didConnectPeer: peripheral.identifier)
        MeshLogger.ble.info("Connected to \(peripheral.identifier)")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MeshLogger.ble.error("Failed to connect \(peripheral.identifier): \(error?.localizedDescription ?? "unknown")")
        discoveredPeripherals.removeValue(forKey: peripheral.identifier)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripherals.removeValue(forKey: peripheral.identifier)
        peripheralCharacteristics.removeValue(forKey: peripheral.identifier)
        peers[peripheral.identifier]?.isConnected = false
        disconnectTimestamps[peripheral.identifier] = Date()
        delegate?.centralManager(didDisconnectPeer: peripheral.identifier)
        MeshLogger.ble.info("Disconnected from \(peripheral.identifier)")
    }
}

// MARK: - CBPeripheralDelegate
extension BLECentralManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == BLEConstants.serviceUUID {
            peripheral.discoverCharacteristics([BLEConstants.characteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == BLEConstants.characteristicUUID {
            peripheralCharacteristics[peripheral.identifier] = characteristic

            // Subscribe to notifications
            peripheral.setNotifyValue(true, for: characteristic)
            MeshLogger.ble.debug("Subscribed to notifications from \(peripheral.identifier)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            MeshLogger.ble.error("didUpdateValue error from \(peripheral.identifier): \(error.localizedDescription)")
            return
        }
        guard let data = characteristic.value else {
            MeshLogger.ble.warning("didUpdateValue: nil data from \(peripheral.identifier)")
            return
        }
        MeshLogger.ble.info("Received \(data.count) bytes from \(peripheral.identifier)")
        peers[peripheral.identifier]?.lastSeen = Date()
        delegate?.centralManager(didReceiveData: data, from: peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            MeshLogger.ble.error("Write error to \(peripheral.identifier): \(error.localizedDescription)")
        }
    }
}
