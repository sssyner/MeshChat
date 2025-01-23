import UIKit
import FirebaseCore
import CoreBluetooth
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Firebase - graceful init (won't crash with placeholder plist)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // Check if launched due to BLE state restoration
        if let centralIDs = launchOptions?[.bluetoothCentrals] as? [String] {
            MeshLogger.ble.info("Launched for BLE central restoration: \(centralIDs)")
        }
        if let peripheralIDs = launchOptions?[.bluetoothPeripherals] as? [String] {
            MeshLogger.ble.info("Launched for BLE peripheral restoration: \(peripheralIDs)")
        }

        MeshLogger.general.info("Application didFinishLaunching")
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
