import SwiftUI

enum DangerType: String, Codable, CaseIterable, Identifiable {
    case fire
    case flood
    case earthquake
    case help
    case info

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fire: return "火災"
        case .flood: return "洪水"
        case .earthquake: return "地震"
        case .help: return "救助要請"
        case .info: return "情報"
        }
    }

    var icon: String {
        switch self {
        case .fire: return "flame.fill"
        case .flood: return "drop.triangle.fill"
        case .earthquake: return "waveform.path.ecg"
        case .help: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .fire: return .red
        case .flood: return .blue
        case .earthquake: return .orange
        case .help: return .yellow
        case .info: return .green
        }
    }
}
