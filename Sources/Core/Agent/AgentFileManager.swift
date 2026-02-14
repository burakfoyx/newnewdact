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
    /// Uses download URL to avoid FileSizeTooLargeException for large history files.
    func readMetrics() async throws -> AgentMetricsExport {
        // 1. Get signed download URL
        let downloadUrl = try await client.getFileDownloadUrl(serverId: agentServerID, filePath: "data/metrics.json")
        
        print("⬇️ Downloading metrics.json from: \(downloadUrl)")
        
        // 2. Download content
        let (data, response) = try await URLSession.shared.data(from: downloadUrl)
        
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw AgentFileError.fileNotFound // Or newer error type
        }
        
        // Debug: Log first 100 chars to verify content
        if let preview = String(data: data.prefix(200), encoding: .utf8) {
            print("📄 metrics.json content preview: \(preview)...")
        }
        
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
        
        do {
            return try decoder.decode(AgentMetricsExport.self, from: data)
        } catch {
            // Create a preview of the JSON to help debugging
            let preview = String(data: data.prefix(500), encoding: .utf8) ?? "Unreadable Data"
            
            // Detailed error message
            var errorMsg = "Decoding Failed: \(error.localizedDescription)"
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let ctx):
                    errorMsg = "Missing Key: '\(key.stringValue)' at path: \(ctx.codingPath)"
                case .valueNotFound(let type, let ctx):
                    errorMsg = "Missing Value for type: \(type) at path: \(ctx.codingPath)"
                case .typeMismatch(let type, let ctx):
                    errorMsg = "Type Mismatch: Expected \(type), at path: \(ctx.codingPath)"
                case .dataCorrupted(let ctx):
                    errorMsg = "Data Corrupted: \(ctx.debugDescription)"
                @unknown default:
                    errorMsg = "Unknown Decoding Error"
                }
            }
            
            print("❌ \(errorMsg)")
            print("📄 JSON Preview: \(preview)")
            
            // Throw a descriptive error that the UI can show
            throw NSError(domain: "AgentFileManager", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "\(errorMsg)\n\nJSON Head: \(preview)"
            ])
        }
    }
}

// MARK: - Metric Types

struct AgentMetricsExport: Decodable {
    let generatedAt: Date
    let servers: [String: [AgentResourceSnapshot]?]
    
    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case servers
    }
}

struct AgentResourceSnapshot: Decodable {
    let timestamp: Date
    let cpuPercent: Double
    let memBytes: Int64
    let memLimit: Int64
    let diskBytes: Int64
    let diskLimit: Int64
    let netRx: Int64
    let netTx: Int64
    let uptimeMs: Int64
    
    enum CodingKeys: String, CodingKey {
        case timestamp
        case cpuPercent = "cpu_percent"
        case memBytes = "mem_bytes"
        case memLimit = "mem_limit"
        case diskBytes = "disk_bytes"
        case diskLimit = "disk_limit"
        case netRx = "net_rx"
        case netTx = "net_tx"
        case uptimeMs = "uptime_ms"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Timestamp is required, but we should be robust about it too if possible, 
        // effectively if timestamp is missing, the whole point is moot, so try decode.
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        // Use default values for missing fields to support older metrics.json versions
        cpuPercent = try container.decodeIfPresent(Double.self, forKey: .cpuPercent) ?? 0
        memBytes = try container.decodeIfPresent(Int64.self, forKey: .memBytes) ?? 0
        memLimit = try container.decodeIfPresent(Int64.self, forKey: .memLimit) ?? 0
        diskBytes = try container.decodeIfPresent(Int64.self, forKey: .diskBytes) ?? 0
        diskLimit = try container.decodeIfPresent(Int64.self, forKey: .diskLimit) ?? 0
        netRx = try container.decodeIfPresent(Int64.self, forKey: .netRx) ?? 0
        netTx = try container.decodeIfPresent(Int64.self, forKey: .netTx) ?? 0
        uptimeMs = try container.decodeIfPresent(Int64.self, forKey: .uptimeMs) ?? 0
    }
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
