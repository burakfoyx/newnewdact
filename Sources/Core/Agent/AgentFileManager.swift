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
    func readLogs() async throws -> String {
        return try await client.getFileContent(serverId: agentServerID, filePath: "data/logs/agent.log")
    }
    
    // MARK: - User Management
// ...
    // MARK: - Metrics
    
    /// Reads metrics.json from the agent container.
    func readMetrics() async throws -> AgentMetricsExport {
        let content = try await client.getFileContent(serverId: agentServerID, filePath: "data/metrics.json")
        let data = Data(content.utf8)
        let decoder = JSONDecoder()
        
        // Go's time.Time marshals to RFC3339 string
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ" // simplified ISO8601
        // Better: use ISO8601DateFormatter
        decoder.dateDecodingStrategy = .iso8601
        
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
