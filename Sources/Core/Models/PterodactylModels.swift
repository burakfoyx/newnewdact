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

struct ServerAttributes: Codable, Identifiable, Hashable {
    public var id: String { uuid }
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
    
    static func == (lhs: ServerAttributes, rhs: ServerAttributes) -> Bool {
        lhs.uuid == rhs.uuid
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(uuid)
    }
}

struct SftpDetails: Codable {
    let ip: String
    let port: Int
}

struct ServerLimits: Codable {
    let memory, swap, disk, io, cpu: Int?
    let threads: String? // sometimes string or int, usually null in client API
    
    init(memory: Int?, swap: Int?, disk: Int?, io: Int?, cpu: Int?, threads: String? = nil) {
        self.memory = memory
        self.swap = swap
        self.disk = disk
        self.io = io
        self.cpu = cpu
        self.threads = threads
    }
}

struct FeatureLimits: Codable {
    let databases, allocations: Int?
    let backups: Int
    
    init(databases: Int?, allocations: Int?, backups: Int) {
        self.databases = databases
        self.allocations = allocations
        self.backups = backups
    }
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
    let ipAlias: String?
    
    enum CodingKeys: String, CodingKey {
        case id, ip, port, notes
        case isDefault = "is_default"
        case ipAlias = "ip_alias"
    }
}

struct WebsocketResponse: Codable {
    let data: WebsocketData
    
    struct Stats: Codable {
        let memory_bytes: Int64
        let cpu_absolute: Double
        let disk_bytes: Int64
        let state: String
        let uptime: Int64?
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
    let uptime: Int64?
    
    enum CodingKeys: String, CodingKey {
        case memoryBytes = "memory_bytes"
        case cpuAbsolute = "cpu_absolute"
        case diskBytes = "disk_bytes"
        case networkRxBytes = "network_rx_bytes"
        case networkTxBytes = "network_tx_bytes"
        case uptime
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



// MARK: - API Keys
struct ApiKeyResponse: Codable {
    let data: [ApiKeyData]
}
struct ApiKeyData: Codable, Identifiable {
    let object: String
    let attributes: ApiKeyAttributes
    var id: String { attributes.identifier }
}
struct ApiKeyAttributes: Codable {
    let identifier: String
    let description: String
    let allowedIps: [String]
    let lastUsedAt: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case identifier, description
        case allowedIps = "allowed_ips"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
    }
}

// MARK: - Application API Models (Admin Only)

// Node Models
struct NodeListResponse: Codable {
    let object: String
    let data: [NodeData]
}

struct NodeData: Codable {
    let attributes: NodeAttributes
}

struct NodeAttributes: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let locationId: Int
    let fqdn: String
    let scheme: String
    let memory: Int
    let memoryOverallocate: Int
    let disk: Int
    let diskOverallocate: Int
    let uploadSize: Int
    let daemonListen: Int
    let daemonSftp: Int
    let maintenanceMode: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, fqdn, scheme, memory, disk
        case locationId = "location_id"
        case memoryOverallocate = "memory_overallocate"
        case diskOverallocate = "disk_overallocate"
        case uploadSize = "upload_size"
        case daemonListen = "daemon_listen"
        case daemonSftp = "daemon_sftp"
        case maintenanceMode = "maintenance_mode"
    }
}

// Nest Models
struct NestListResponse: Codable {
    let object: String
    let data: [NestData]
}

struct NestData: Codable {
    let attributes: NestAttributes
}

struct NestAttributes: Codable, Identifiable {
    let id: Int
    let uuid: String
    let author: String
    let name: String
    let description: String?
}

// Egg Models
struct EggListResponse: Codable {
    let object: String
    let data: [EggData]
}

struct EggData: Codable {
    let attributes: EggAttributes
}

struct EggAttributes: Codable, Identifiable {
    let id: Int
    let uuid: String
    let name: String
    let description: String?
    let dockerImage: String
    let startup: String
    let relationships: EggRelationships?
    
    enum CodingKeys: String, CodingKey {
        case id, uuid, name, description, startup, relationships
        case dockerImage = "docker_image"
    }
    
    /// Get default environment variables from egg variables
    var defaultEnvironment: [String: String] {
        guard let variables = relationships?.variables?.data else { return [:] }
        var env: [String: String] = [:]
        for variable in variables {
            env[variable.attributes.envVariable] = variable.attributes.defaultValue
        }
        return env
    }
}

struct EggRelationships: Codable {
    let variables: EggVariableList?
}

struct EggVariableList: Codable {
    let data: [EggVariableData]
}

struct EggVariableData: Codable {
    let attributes: EggVariable
}

struct EggVariable: Codable {
    let id: Int
    let name: String
    let description: String?
    let envVariable: String
    let defaultValue: String
    let rules: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, rules
        case envVariable = "env_variable"
        case defaultValue = "default_value"
    }
}

// Application Allocation Models
struct ApplicationAllocationResponse: Codable {
    let object: String
    let data: [ApplicationAllocationData]
}

struct ApplicationAllocationData: Codable {
    let attributes: ApplicationAllocation
}

struct ApplicationAllocation: Codable, Identifiable {
    let id: Int
    let ip: String
    let alias: String?
    let port: Int
    let notes: String?
    let assigned: Bool
}

// User Info Response (Client API)
struct UserInfoResponse: Codable {
    let attributes: UserInfo
}

struct UserInfo: Codable {
    let id: Int
    let admin: Bool
    let username: String
    let email: String
    let firstName: String
    let lastName: String
    
    enum CodingKeys: String, CodingKey {
        case id, admin, username, email
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

// MARK: - Application User Models
struct ApplicationUser: Codable, Identifiable {
    let id: Int
    let externalId: String?
    let uuid: String
    let username: String
    let email: String
    let firstName: String
    let lastName: String
    let language: String
    let rootAdmin: Bool
    let twoFactorEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, uuid, username, email, language
        case externalId = "external_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case rootAdmin = "root_admin"
        case twoFactorEnabled = "2fa"
    }
}

// MARK: - Application Server Models (For Create Response)
struct ApplicationServerResponse: Codable {
    let object: String
    let attributes: ApplicationServerAttributes
}

struct ApplicationServerAttributes: Codable, Identifiable {
    let id: Int
    let externalId: String?
    let uuid: String
    let identifier: String
    let name: String
    let description: String?
    let suspended: Bool
    let limits: ServerLimits
    let featureLimits: FeatureLimits
    let user: Int
    let node: Int
    let allocation: Int
    let nest: Int
    let egg: Int
    
    enum CodingKeys: String, CodingKey {
        case id, uuid, identifier, name, description, suspended, limits, user, node, allocation, nest, egg
        case externalId = "external_id"
        case featureLimits = "feature_limits"
    }
}
