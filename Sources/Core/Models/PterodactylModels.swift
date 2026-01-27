import Foundation

struct PterodactylMeta: Codable {
    let pagination: Pagination?
}

struct Pagination: Codable {
    let total, count, perPage, currentPage, totalPages: Int
    
    enum CodingKeys: String, CodingKey {
        case total, count
        case perPage = "per_page"
        case currentPage = "current_page"
        case totalPages = "total_pages"
    }
}

// MARK: - Server Response
struct ServerListResponse: Codable {
    let object: String
    let data: [ServerData]
    let meta: PterodactylMeta
}

struct ServerData: Codable, Identifiable {
    let object: String
    let attributes: ServerAttributes
    
    var id: String { attributes.uuid }
}

struct ServerAttributes: Codable {
    let serverOwner: Bool
    let identifier: String
    let uuid: String
    let name: String
    let node: String
    let sftpDetails: SftpDetails
    let description: String
    let limits: ServerLimits
    let featureLimits: FeatureLimits
    let isSuspended: Bool
    let isInstalling: Bool
    let relationships: ServerRelationships?

    enum CodingKeys: String, CodingKey {
        case serverOwner = "server_owner"
        case identifier, uuid, name, node
        case sftpDetails = "sftp_details"
        case description, limits
        case featureLimits = "feature_limits"
        case isSuspended = "is_suspended"
        case isInstalling = "is_installing"
        case relationships
    }
}

struct SftpDetails: Codable {
    let ip: String
    let port: Int
}

struct ServerLimits: Codable {
    let memory, swap, disk, io, cpu: Int?
    let threads: String? // sometimes string or int, usually null in client API
}

struct FeatureLimits: Codable {
    let databases, allocations, backups: Int
}

struct ServerRelationships: Codable {
    let allocations: AllocationResponse?
}

struct AllocationResponse: Codable {
    let data: [AllocationData]
}

struct AllocationData: Codable {
    let attributes: AllocationAttributes
}

struct AllocationAttributes: Codable {
    let id: Int
    let ip: String
    let port: Int
    let isDefault: Bool
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id, ip, port, notes
        case isDefault = "is_default"
    }
}

struct WebsocketResponse: Codable {
    let data: WebsocketData
    
    struct Stats: Codable {
        let memory_bytes: Int64
        let cpu_absolute: Double
        let disk_bytes: Int64
        let state: String
    }
}

struct ServerStatsResponse: Codable {
    let object: String
    let attributes: ServerStats
}

struct ServerStats: Codable {
    let currentState: String
    let isSuspended: Bool
    let resources: ResourceUsage
    
    enum CodingKeys: String, CodingKey {
        case currentState = "current_state"
        case isSuspended = "is_suspended"
        case resources
    }
}

struct ResourceUsage: Codable {
    let memoryBytes: Int64
    let cpuAbsolute: Double
    let diskBytes: Int64
    let networkRxBytes: Int64
    let networkTxBytes: Int64
    
    enum CodingKeys: String, CodingKey {
        case memoryBytes = "memory_bytes"
        case cpuAbsolute = "cpu_absolute"
        case diskBytes = "disk_bytes"
        case networkRxBytes = "network_rx_bytes"
        case networkTxBytes = "network_tx_bytes"
    }
}

struct WebsocketData: Codable {
    let token: String
    let socket: String
}

// MARK: - Databases
struct DatabaseResponse: Codable {
    let data: [DatabaseData]
}
struct DatabaseData: Codable, Identifiable {
    let object: String
    let attributes: DatabaseAttributes
    var id: String { attributes.id }
}
struct DatabaseAttributes: Codable {
    let id: String
    let name: String
    let username: String
    let host: DatabaseHost
    
    enum CodingKeys: String, CodingKey {
        case id, name, username, host
    }
}
struct DatabaseHost: Codable {
    let address: String
    let port: Int
}

// MARK: - Schedules
struct ScheduleResponse: Codable {
    let data: [ScheduleData]
}
struct ScheduleData: Codable, Identifiable {
    let object: String
    let attributes: ScheduleAttributes
    var id: Int { attributes.id }
}
struct ScheduleAttributes: Codable {
    let id: Int
    let name: String
    let isActive: Bool
    let isProcessing: Bool
    let cron: ScheduleCron
    let lastRunAt: String?
    let nextRunAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, cron
        case isActive = "is_active"
        case isProcessing = "is_processing"
        case lastRunAt = "last_run_at"
        case nextRunAt = "next_run_at"
    }
}
struct ScheduleCron: Codable {
    let dayOfWeek, dayOfMonth, hour, minute: String
    
    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "day_of_week"
        case dayOfMonth = "day_of_month"
        case hour, minute
    }
}

// MARK: - Users (Subusers)
struct SubuserResponse: Codable {
    let data: [SubuserData]
}
struct SubuserData: Codable, Identifiable {
    let object: String
    let attributes: SubuserAttributes
    var id: String { attributes.uuid }
}
struct SubuserAttributes: Codable {
    let uuid: String
    let username: String
    let email: String
    let image: String?
    let twoFactorEnabled: Bool
    let permissions: [String]
    
    enum CodingKeys: String, CodingKey {
        case uuid, username, email, image, permissions
        case twoFactorEnabled = "2fa_enabled"
    }
}


