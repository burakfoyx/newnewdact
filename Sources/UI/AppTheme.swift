import SwiftUI

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case blue = "Ocean Blue"
    case purple = "Nebula Purple"
    case red = "Mars Red"
    case green = "Forest Green"
    case gold = "Luxury Gold"
    
    var id: String { rawValue }
    
    var accentColor: Color {
        switch self {
        case .blue: return .blue
        case .purple: return .purple
        case .red: return .red
        case .green: return .green
        case .gold: return .orange
        }
    }
}
