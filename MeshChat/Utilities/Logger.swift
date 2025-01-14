import Foundation
import os

enum MeshLogger {
    private static let subsystem = "com.synergyhq.meshchat"

    static let ble = os.Logger(subsystem: subsystem, category: "BLE")
    static let mesh = os.Logger(subsystem: subsystem, category: "Mesh")
    static let storage = os.Logger(subsystem: subsystem, category: "Storage")
    static let sync = os.Logger(subsystem: subsystem, category: "Sync")
    static let general = os.Logger(subsystem: subsystem, category: "General")

    // File-based debug log for diagnostic export
    private static let logFileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("meshchat_debug.log")
    }()

    static func fileLog(_ category: String, _ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] [\(category)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let handle = try? FileHandle(forWritingTo: logFileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }

    static func readLogFile() -> String {
        (try? String(contentsOf: logFileURL, encoding: .utf8)) ?? ""
    }

    static func clearLogFile() {
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
    }
}
