import Foundation

/// Manages reading/writing agent files via the Pterodactyl File API.
///
/// The agent stores its control.json in `/control/` and status/logs in `/data/`.
/// This actor provides thread-safe access to those files through the panel's file API.
actor AgentFileManager {
    
    private let client: PterodactylClient
    private let agentServerID: String
    
    init(client: PterodactylClient = .shared, agentServerID: String) {
        self.client = client
        self.agentServerID = agentServerID
    }
    
    // MARK: - Control File (App → Agent)
    
    /// Reads the current control.json from the agent container.
    func readControlFile() async throws -> AgentControl {
        let content = try await client.getFileContent(serverId: agentServerID, filePath: "control/control.json")
        let data = Data(content.utf8)
        return try JSONDecoder().decode(AgentControl.self, from: data)
    }
    
    /// Writes control.json to the agent container.
    /// Automatically increments the version and sets the timestamp.
    func writeControlFile(_ control: AgentControl) async throws {
        var updated = control
        updated.version += 1
        updated.updatedAt = Int(Date().timeIntervalSince1970)
        
        print("📝 Writing control.json (v\(updated.version)) to control/control.json ...")
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(updated)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw AgentFileError.encodingFailed
        }
        
        try await client.writeFileContent(serverId: agentServerID, filePath: "control/control.json", content: jsonString)
        print("✅ Successfully wrote control.json")
    }
    
    // MARK: - Status File (Agent → App)
    
    /// Reads status.json from the agent container.
    func readStatus() async throws -> AgentStatus {
        let content = try await client.getFileContent(serverId: agentServerID, filePath: "data/status.json")
        let data = Data(content.utf8)
        return try JSONDecoder().decode(AgentStatus.self, from: data)
    }
    
    // MARK: - Logs
    
    /// Reads the latest agent log lines.
    /// Reads the latest agent log lines.
    func readLogs() async throws -> String {
        let content = try await client.getFileContent(serverId: agentServerID, filePath: "data/logs/agent.log")
        if !content.isEmpty {
            return content
        }
        
        // Fallback to rotated log if main log is empty (just rotated)
        do {
            return try await client.getFileContent(serverId: agentServerID, filePath: "data/logs/agent.log.1")
        } catch {
            return "" // Return empty if no rotated log exists
        }
    }
    
    // MARK: - User Management
    
    /// Adds or updates a user in control.json.
    /// Encrypts the API key before writing.
    func upsertUser(
        userUUID: String,
        apiKey: String,
        agentSecret: String,
        isAdmin: Bool,
        allowedServers: [String],
        deviceToken: String?
    ) async throws {
        var control: AgentControl
        do {
            control = try await readControlFile()
        } catch {
            // If control file doesn't exist yet, start fresh
            control = AgentControl.empty
        }
        
        let encryptedKey = try AgentCrypto.encrypt(apiKey, secret: agentSecret)
        
        var tokens: [String] = []
        if let token = deviceToken {
            tokens = [token]
        }
        
        if let existingIndex = control.users.firstIndex(where: { $0.userUUID == userUUID }) {
            // Update existing user
            var existing = control.users[existingIndex]
            existing.apiKeyEncrypted = encryptedKey
            existing.isAdmin = isAdmin
            existing.allowedServers = allowedServers
            
            // Merge device tokens (don't lose existing ones)
            if let token = deviceToken, !existing.deviceTokens.contains(token) {
                existing.deviceTokens.append(token)
            }
            control.users[existingIndex] = existing
        } else {
            // Add new user
            let newUser = AgentControlUser(
                userUUID: userUUID,
                apiKeyEncrypted: encryptedKey,
                isAdmin: isAdmin,
                allowedServers: allowedServers,
                deviceTokens: tokens
            )
            control.users.append(newUser)
        }
        
        try await writeControlFile(control)
    }
    
    /// Removes a user from control.json.
    func removeUser(userUUID: String) async throws {
        var control = try await readControlFile()
        control.users.removeAll { $0.userUUID == userUUID }
        control.alerts.removeAll { $0.userUUID == userUUID }
        control.automations.removeAll { $0.userUUID == userUUID }
        try await writeControlFile(control)
    }
    
    /// Updates the device token for a user (e.g. after APNs token refresh).
    func updateDeviceToken(userUUID: String, newToken: String) async throws {
        var control = try await readControlFile()
        if let idx = control.users.firstIndex(where: { $0.userUUID == userUUID }) {
            if !control.users[idx].deviceTokens.contains(newToken) {
                control.users[idx].deviceTokens.append(newToken)
            }
            try await writeControlFile(control)
        }
    }
    
    // MARK: - Alert Management
    
    /// Syncs alert rules for a user to control.json.
    func syncAlerts(_ alerts: [AgentAlertRule], forUser userUUID: String) async throws {
        var control = try await readControlFile()
        // Remove old alerts for this user, add new ones
        control.alerts.removeAll { $0.userUUID == userUUID }
        control.alerts.append(contentsOf: alerts)
        try await writeControlFile(control)
    }
    
    /// Adds a single alert rule.
    func addAlert(_ alert: AgentAlertRule) async throws {
        var control = try await readControlFile()
        control.alerts.append(alert)
        try await writeControlFile(control)
    }
    
    /// Removes a single alert rule by ID.
    func removeAlert(id: String) async throws {
        var control = try await readControlFile()
        control.alerts.removeAll { $0.id == id }
        try await writeControlFile(control)
    }
    
    // MARK: - Automation Management
    
    /// Syncs automation rules for a user to control.json.
    func syncAutomations(_ automations: [AgentAutomationRule], forUser userUUID: String) async throws {
        var control = try await readControlFile()
        control.automations.removeAll { $0.userUUID == userUUID }
        control.automations.append(contentsOf: automations)
        try await writeControlFile(control)
    }
    
    /// Adds a single automation rule.
    func addAutomation(_ automation: AgentAutomationRule) async throws {
        var control = try await readControlFile()
        control.automations.append(automation)
        try await writeControlFile(control)
    }
    
    /// Removes a single automation rule by ID.
    func removeAutomation(id: String) async throws {
        var control = try await readControlFile()
        control.automations.removeAll { $0.id == id }
        try await writeControlFile(control)
    }
    // MARK: - Metrics
    
    /// Reads metrics.json from the agent container.
    /// Reads metrics.json from the agent container.
    func readMetrics() async throws -> AgentMetricsExport {
        let content = try await client.getFileContent(serverId: agentServerID, filePath: "data/metrics.json")
        
        // Debug: Log first 100 chars to verify content
        let preview = String(content.prefix(200))
        print("📄 metrics.json content preview: \(preview)...")
        
        let data = Data(content.utf8)
        let decoder = JSONDecoder()
        
        // Go's time.Time marshals to RFC3339 string (often with fractional seconds)
        // Standard .iso8601 strategy in Swift often fails on fractional seconds.
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateStr = try container.decode(String.self)
            
            // Try standard ISO8601 (upto nanos)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateStr) {
                return date
            }
            
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateStr) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(dateStr)"
            )
        }
        
        return try decoder.decode(AgentMetricsExport.self, from: data)
    }
}

// MARK: - Metric Types

struct AgentMetricsExport: Decodable {
    let generated_at: Date
    let servers: [String: [AgentResourceSnapshot]]
}

struct AgentResourceSnapshot: Decodable {
    let timestamp: Date
    let cpu_percent: Double
    let mem_bytes: Int64
    let mem_limit: Int64
    let disk_bytes: Int64
    let disk_limit: Int64
    let net_rx: Int64
    let net_tx: Int64
    let uptime_ms: Int64
}

enum AgentFileError: LocalizedError {
    case encodingFailed
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode control data"
        case .fileNotFound: return "Agent file not found"
        }
    }
}
