import Foundation
import CoreBluetooth
import os

protocol BLEPeripheralManagerDelegate: AnyObject {
    func peripheralManager(didReceiveData data: Data, from central: CBCentral)
}

final class BLEPeripheralManager: NSObject {
    private var peripheralManager: CBPeripheralManager!
    private var meshCharacteristic: CBMutableCharacteristic?
    private var subscribedCentrals: [CBCentral] = []

    weak var delegate: BLEPeripheralManagerDelegate?

    private(set) var isAdvertising = false

    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: DispatchQueue(label: "com.meshchat.peripheral", qos: .userInitiated),
            options: [CBPeripheralManagerOptionRestoreIdentifierKey: BLEConstants.peripheralRestorationID]
        )
    }

    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else {
            MeshLogger.ble.warning("Peripheral not powered on, cannot advertise")
            return
        }

        setupService()

        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [BLEConstants.serviceUUID],
            CBAdvertisementDataLocalNameKey: "MeshChat"
        ])
        isAdvertising = true
        MeshLogger.ble.info("Started advertising")
    }

    func stopAdvertising() {
        peripheralManager.stopAdvertising()
        isAdvertising = false
        MeshLogger.ble.info("Stopped advertising")
    }

    func sendToSubscribers(_ data: Data) {
        guard let characteristic = meshCharacteristic else { return }

        let success = peripheralManager.updateValue(
            data,
            for: characteristic,
            onSubscribedCentrals: nil
        )

        if !success {
            MeshLogger.ble.warning("Failed to send update to subscribers (queue full)")
        } else {
            MeshLogger.ble.debug("Sent \(data.count) bytes to \(self.subscribedCentrals.count) subscribers")
        }
    }

    var subscriberCount: Int { subscribedCentrals.count }

    // MARK: - Private

    private func setupService() {
        guard meshCharacteristic == nil else { return }

        let characteristic = CBMutableCharacteristic(
            type: BLEConstants.characteristicUUID,
            properties: [.read, .write, .writeWithoutResponse, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )

        let service = CBMutableService(type: BLEConstants.serviceUUID, primary: true)
        service.characteristics = [characteristic]

        peripheralManager.add(service)
        meshCharacteristic = characteristic
        MeshLogger.ble.debug("GATT service configured")
    }
}

// MARK: - CBPeripheralManagerDelegate
extension BLEPeripheralManager: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        MeshLogger.ble.info("Peripheral state: \(peripheral.state.rawValue)")
        if peripheral.state == .poweredOn {
            startAdvertising()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        MeshLogger.ble.info("Peripheral willRestoreState")
        // Restore services if needed
        if let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] {
            for service in services {
                if let chars = service.characteristics {
                    for char in chars {
                        if char.uuid == BLEConstants.characteristicUUID {
                            meshCharacteristic = char as? CBMutableCharacteristic
                        }
                    }
                }
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if !subscribedCentrals.contains(where: { $0.identifier == central.identifier }) {
            subscribedCentrals.append(central)
        }
        MeshLogger.ble.info("Central subscribed. Total: \(self.subscribedCentrals.count)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscribedCentrals.removeAll { $0.identifier == central.identifier }
        MeshLogger.ble.info("Central unsubscribed. Total: \(self.subscribedCentrals.count)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let data = request.value {
                MeshLogger.ble.info("Received write: \(data.count) bytes from \(request.central.identifier)")
                delegate?.peripheralManager(didReceiveData: data, from: request.central)
            } else {
                MeshLogger.ble.warning("Received write with nil data from \(request.central.identifier)")
            }
            peripheral.respond(to: request, withResult: .success)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        // Respond with empty data for reads — actual data flows via notify/write
        request.value = Data()
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        MeshLogger.ble.debug("Peripheral ready to update subscribers")
    }
}
