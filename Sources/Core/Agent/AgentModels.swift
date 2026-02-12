import Foundation

// MARK: - Control File (written by app, read by agent)

/// Represents the full control.json document synced to the agent via Pterodactyl File API.
struct AgentControl: Codable {
    var version: Int
    var updatedAt: Int // Unix timestamp
    var users: [AgentControlUser]
    var alerts: [AgentAlertRule]
    var automations: [AgentAutomationRule]
    
    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case users, alerts, automations
    }
    
    static let empty = AgentControl(version: 0, updatedAt: 0, users: [], alerts: [], automations: [])
}

/// A user entry in control.json.
struct AgentControlUser: Codable, Identifiable {
    var id: String { userUUID }
    let userUUID: String
    var apiKeyEncrypted: String
    var isAdmin: Bool
    var allowedServers: [String]
    var deviceTokens: [String]
    
    enum CodingKeys: String, CodingKey {
        case userUUID = "user_uuid"
        case apiKeyEncrypted = "api_key_encrypted"
        case isAdmin = "is_admin"
        case allowedServers = "allowed_servers"
        case deviceTokens = "device_tokens"
    }
}

/// An alert rule in control.json.
struct AgentAlertRule: Codable, Identifiable {
    let id: String
    let userUUID: String
    let serverID: String
    var conditionType: String
    var threshold: Double
    var duration: Int       // seconds the condition must hold
    var cooldown: Int       // seconds between triggers
    var enabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userUUID = "user_uuid"
        case serverID = "server_id"
        case conditionType = "condition_type"
        case threshold, duration, cooldown, enabled
    }
}

/// An automation rule in control.json.
struct AgentAutomationRule: Codable, Identifiable {
    let id: String
    let userUUID: String
    let serverID: String
    var triggerType: String
    var triggerConfig: [String: Double]
    var action: String
    var actionConfig: [String: String]
    var cooldown: Int
    var enabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userUUID = "user_uuid"
        case serverID = "server_id"
        case triggerType = "trigger_type"
        case triggerConfig = "trigger_config"
        case action
        case actionConfig = "action_config"
        case cooldown, enabled
    }
}

// MARK: - Status File (written by agent, read by app)

/// Represents status.json written by the agent.
struct AgentStatus: Codable {
    let agentVersion: String
    let uptimeSeconds: Int64
    let lastSampleAt: String
    let controlVersion: Int
    let usersCount: Int
    let activeAlerts: Int
    let activeAutomations: Int
    let serversMonitored: Int
    let dbSizeBytes: Int64?
    let errors: [String]?
    
    enum CodingKeys: String, CodingKey {
        case agentVersion = "agent_version"
        case uptimeSeconds = "uptime_seconds"
        case lastSampleAt = "last_sample_at"
        case controlVersion = "control_version"
        case usersCount = "users_count"
        case activeAlerts = "active_alerts"
        case activeAutomations = "active_automations"
        case serversMonitored = "servers_monitored"
        case dbSizeBytes = "db_size_bytes"
        case errors
    }
    
    /// Returns true if the agent sampled within the last 2 minutes.
    var isHealthy: Bool {
        guard let date = ISO8601DateFormatter().date(from: lastSampleAt) else { return false }
        return Date().timeIntervalSince(date) < 120
    }
    
    /// Formatted uptime string.
    var uptimeFormatted: String {
        let hours = uptimeSeconds / 3600
        let minutes = (uptimeSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
