import SwiftUI

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case blue = "Ocean Blue"
    case purple = "Nebula Purple"
    case red = "Mars Red"
    case green = "Forest Green"
    case gold = "Luxury Gold"
    
    var id: String { rawValue }
    
    var gradientColors: [Color] {
        switch self {
        case .blue: return [.blue.opacity(0.4), .cyan.opacity(0.3), .indigo.opacity(0.4)]
        case .purple: return [.purple.opacity(0.4), .pink.opacity(0.3), .indigo.opacity(0.4)]
        case .red: return [.red.opacity(0.4), .orange.opacity(0.3), .purple.opacity(0.4)]
        case .green: return [.green.opacity(0.4), .mint.opacity(0.3), .teal.opacity(0.4)]
        case .gold: return [.orange.opacity(0.4), .yellow.opacity(0.3), .brown.opacity(0.4)]
        }
    }
    var mainColor: Color {
        gradientColors.first ?? .blue
    }
}
