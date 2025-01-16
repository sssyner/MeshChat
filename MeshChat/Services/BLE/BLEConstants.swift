import CoreBluetooth

enum BLEConstants {
    static let serviceUUID = CBUUID(string: "12345678-1234-5678-1234-56789ABCDEF0")
    static let characteristicUUID = CBUUID(string: "12345678-1234-5678-1234-56789ABCDEF1")
    static let centralRestorationID = "com.meshchat.ble.central"
    static let peripheralRestorationID = "com.meshchat.ble.peripheral"
}
