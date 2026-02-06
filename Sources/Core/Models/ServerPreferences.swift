import Foundation
import SwiftData

// MARK: - Server Group Model

@Model
final class ServerGroup {
    var id: UUID
    var name: String
    var colorHex: String  // Hex color like "#FF5733"
    var icon: String      // SF Symbol name
    var serverIds: [String]  // Server identifiers in this group
    var sortOrder: Int
    var createdAt: Date
    
    init(
        name: String,
        colorHex: String = "#007AFF",
        icon: String = "folder.fill",
        serverIds: [String] = [],
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.serverIds = serverIds
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

// MARK: - Server Customization (labels, colors, favorites)

@Model
final class ServerCustomization {
    @Attribute(.unique) var serverId: String
    var customName: String?       // Override display name
    var colorHex: String?         // Custom color
    var icon: String?             // Custom SF Symbol
    var isFavorite: Bool
    var isPinned: Bool            // New: Brings servers to top
    var sortOrder: Int            // New: Manual sorting order
    var notes: String?            // Personal notes
    var tags: [String]            // Custom tags
    var updatedAt: Date
    
    init(serverId: String) {
        self.serverId = serverId
        self.customName = nil
        self.colorHex = nil
        self.icon = nil
        self.isFavorite = false
        self.isPinned = false
        self.sortOrder = 0
        self.notes = nil
        self.tags = []
        self.updatedAt = Date()
    }
}

// MARK: - Quick Actions

enum QuickAction: String, CaseIterable, Identifiable {
    case start = "Start"
    case stop = "Stop"
    case restart = "Restart"
    case kill = "Kill"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .start: return "play.fill"
        case .stop: return "stop.fill"
        case .restart: return "arrow.clockwise"
        case .kill: return "xmark.octagon.fill"
        }
    }
    
    var color: String {
        switch self {
        case .start: return "#34C759"    // Green
        case .stop: return "#FF9500"     // Orange
        case .restart: return "#007AFF"  // Blue
        case .kill: return "#FF3B30"     // Red
        }
    }
    
    var signal: String {
        switch self {
        case .start: return "start"
        case .stop: return "stop"
        case .restart: return "restart"
        case .kill: return "kill"
        }
    }
}

// MARK: - Refresh Interval Settings

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case fast = 5       // 5 seconds (Pro only)
    case normal = 10    // 10 seconds (Pro only)
    case standard = 30  // 30 seconds
    case slow = 60      // 1 minute
    case manual = 0     // Manual only
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .fast: return "5 seconds"
        case .normal: return "10 seconds"
        case .standard: return "30 seconds"
        case .slow: return "1 minute"
        case .manual: return "Manual"
        }
    }
    
    var requiresPro: Bool {
        switch self {
        case .fast, .normal: return true
        default: return false
        }
    }
}

// MARK: - Server Preferences Manager

@MainActor
class ServerPreferencesManager: ObservableObject {
    static let shared = ServerPreferencesManager()
    
    @Published var refreshInterval: RefreshInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval.rawValue, forKey: "refreshInterval")
        }
    }
    
    private init() {
        let savedInterval = UserDefaults.standard.integer(forKey: "refreshInterval")
        self.refreshInterval = RefreshInterval(rawValue: savedInterval) ?? .standard
    }
}

// MARK: - Color Presets

struct ColorPreset: Identifiable {
    let id = UUID()
    let name: String
    let hex: String
    
    static let presets: [ColorPreset] = [
        ColorPreset(name: "Blue", hex: "#007AFF"),
        ColorPreset(name: "Purple", hex: "#AF52DE"),
        ColorPreset(name: "Pink", hex: "#FF2D55"),
        ColorPreset(name: "Red", hex: "#FF3B30"),
        ColorPreset(name: "Orange", hex: "#FF9500"),
        ColorPreset(name: "Yellow", hex: "#FFCC00"),
        ColorPreset(name: "Green", hex: "#34C759"),
        ColorPreset(name: "Teal", hex: "#5AC8FA"),
        ColorPreset(name: "Indigo", hex: "#5856D6"),
        ColorPreset(name: "Gray", hex: "#8E8E93"),
    ]
}

// MARK: - Icon Presets

struct IconPreset: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    
    static let presets: [IconPreset] = [
        IconPreset(name: "Server", symbol: "server.rack"),
        IconPreset(name: "Game", symbol: "gamecontroller.fill"),
        IconPreset(name: "Web", symbol: "globe"),
        IconPreset(name: "Database", symbol: "cylinder.fill"),
        IconPreset(name: "Bot", symbol: "cpu"),
        IconPreset(name: "Cloud", symbol: "cloud.fill"),
        IconPreset(name: "Code", symbol: "chevron.left.forwardslash.chevron.right"),
        IconPreset(name: "Star", symbol: "star.fill"),
        IconPreset(name: "Heart", symbol: "heart.fill"),
        IconPreset(name: "Bolt", symbol: "bolt.fill"),
        IconPreset(name: "Shield", symbol: "shield.fill"),
        IconPreset(name: "Lock", symbol: "lock.fill"),
    ]
}

// MARK: - Helper Extensions

extension String {
    /// Convert hex color string to SwiftUI Color
    var asColor: Color {
        let hex = self.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = (
                Double((int >> 16) & 0xFF) / 255,
                Double((int >> 8) & 0xFF) / 255,
                Double(int & 0xFF) / 255
            )
        default:
            (r, g, b) = (0.5, 0.5, 0.5)
        }
        return Color(red: r, green: g, blue: b)
    }
}

import SwiftUI
