import Foundation

enum AlertMetric: String, Codable, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    case disk = "Disk"
    case network = "Network In"
    case offline = "Offline"
    
    var id: String { rawValue }
    
    var unit: String {
        switch self {
        case .cpu: return "%"
        case .memory: return "%"
        case .disk: return "%"
        case .network: return "MB/s"
        case .offline: return ""
        }
    }
}

enum AlertCondition: String, Codable, CaseIterable, Identifiable {
    case above = "Above"
    case below = "Below"
    
    var id: String { rawValue }
    
    var symbol: String {
        switch self {
        case .above: return ">"
        case .below: return "<"
        }
    }
}
