import Foundation

/// Manages the agent lifecycle: detection, deployment, connection, and health checking.
///
/// Coordinates between `PterodactylClient` (for server creation/discovery),
/// `AgentFileManager` (for file-based communication), and `AccountManager`
/// (for persisting agent credentials).
class AgentManager: ObservableObject {
    
    static let shared = AgentManager()
    
    @Published var agentState: AgentState = .unknown
    @Published var agentStatus: AgentStatus? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    private let client = PterodactylClient.shared
    private var fileManager: AgentFileManager? = nil
    
    /// The agent's server identifier on the panel.
    var agentServerID: String? {
        AccountManager.shared.activeAccount?.agentServerIdentifier
    }
    
    /// The shared secret for encryption.
    var agentSecret: String? {
        AccountManager.shared.activeAccount?.agentSecret
    }
    
    private init() {}
    
    // MARK: - Agent Discovery
    
    /// Detects whether an XYIDactyl Agent server exists on the current panel.
    /// Looks for a server whose name starts with "XYIDactyl Agent".
    @MainActor
    func detectAgent() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let servers = try await client.fetchServers()
            if let agentServer = servers.first(where: { $0.name.hasPrefix("XYIDactyl Agent") }) {
                // Found existing agent
                let identifier = agentServer.identifier
                
                // Persist the identifier if not already saved
                if var account = AccountManager.shared.activeAccount,
                   account.agentServerIdentifier != identifier {
                    account.agentServerIdentifier = identifier
                    AccountManager.shared.updateAccount(account)
                }
                
                self.fileManager = AgentFileManager(agentServerID: identifier)
                agentState = .detected
                
                // Try to read status
                await refreshStatus()
            } else {
                agentState = .notFound
            }
        } catch {
            agentState = .error
            errorMessage = "Failed to detect agent: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Agent Deployment
    
    /// Deploys a new XYIDactyl Agent server on the panel.
    /// Requires admin (Application API) access.
    @MainActor
    func deployAgent(nodeId: Int, allocationId: Int, eggId: Int, userId: Int) async throws {
        guard let account = AccountManager.shared.activeAccount else {
            throw AgentManagerError.noActiveAccount
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // Generate agent credentials
        let agentUUID = UUID().uuidString
        let agentSecretValue = generateSecureSecret()
        
        // Deploy via Application API (admin)
        let environment: [String: String] = [
            "AGENT_UUID": agentUUID,
            "AGENT_SECRET": agentSecretValue,
            "PANEL_URL": account.url,
            "PANEL_API_KEY": account.apiKey,
            "SAMPLING_INTERVAL": "30",
            "RETENTION_DAYS": "30",
            "PUSH_PROVIDER": "dev",
            "LOG_LEVEL": "info"
        ]
        
        let limits = ServerLimits(
            memory: 256,
            swap: 0,
            disk: 1024,
            io: 500,
            cpu: 50,
            threads: nil
        )
        
        let featureLimits = FeatureLimits(
            databases: 0,
            allocations: 1, // Require 1 allocation for the server itself
            backups: 1
        )
        
        let server = try await client.createServer(
            name: "XYIDactyl Agent",
            userId: userId,
            eggId: eggId,
            dockerImage: "ghcr.io/xyidactyl/agent:latest",
            startup: "./entrypoint.sh",
            environment: environment,
            limits: limits,
            featureLimits: featureLimits,
            allocationId: allocationId
        )
        
        // Save agent info to account
        var updatedAccount = account
        updatedAccount.agentServerIdentifier = server.identifier
        updatedAccount.agentSecret = agentSecretValue
        updatedAccount.agentConnected = true
        AccountManager.shared.updateAccount(updatedAccount)
        
        // Initialize file manager
        self.fileManager = AgentFileManager(agentServerID: server.identifier)
        
        // Register current user in control.json
        let servers = try await client.fetchServers()
        let serverIDs = servers.map { $0.identifier }
        
        try await self.fileManager?.upsertUser(
            userUUID: account.id.uuidString,
            apiKey: account.apiKey,
            agentSecret: agentSecretValue,
            isAdmin: account.hasAdminAccess,
            allowedServers: serverIDs,
            deviceToken: nil // Will be set when push permissions are granted
        )
        
        agentState = .connected
    }
    
    // MARK: - Connect User
    
    /// Connects the current user to an existing agent.
    /// Called after agent detection when the user wants to opt in.
    @MainActor
    func connectUser(agentSecret: String) async throws {
        guard let account = AccountManager.shared.activeAccount,
              let serverID = account.agentServerIdentifier else {
            throw AgentManagerError.noAgentDetected
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Save the secret
        var updatedAccount = account
        updatedAccount.agentSecret = agentSecret
        updatedAccount.agentConnected = true
        AccountManager.shared.updateAccount(updatedAccount)
        
        // Initialize file manager if needed
        if fileManager == nil {
            fileManager = AgentFileManager(agentServerID: serverID)
        }
        
        // Get user's accessible servers
        let servers = try await client.fetchServers()
        let serverIDs = servers.map { $0.identifier }
        
        // Register in control.json
        try await fileManager?.upsertUser(
            userUUID: account.id.uuidString,
            apiKey: account.apiKey,
            agentSecret: agentSecret,
            isAdmin: account.hasAdminAccess,
            allowedServers: serverIDs,
            deviceToken: nil
        )
        
        agentState = .connected
        await refreshStatus()
    }
    
    // MARK: - Status
    
    /// Refreshes the agent status by reading status.json.
    @MainActor
    func refreshStatus() async {
        guard let fm = fileManager else { return }
        
        do {
            agentStatus = try await fm.readStatus()
            agentState = agentStatus?.isHealthy == true ? .connected : .unhealthy
        } catch {
            // Status file may not exist yet if agent just started
            agentState = .detected
        }
    }
    
    /// Reads agent log file.
    func readLogs() async throws -> String {
        guard let fm = fileManager else {
            throw AgentManagerError.noAgentDetected
        }
        return try await fm.readLogs()
    }
    
    // MARK: - Alert & Automation Sync
    
    /// Returns the file manager for direct access (alert/automation management).
    func getFileManager() -> AgentFileManager? {
        return fileManager
    }
    
    // MARK: - Helpers
    
    private func generateSecureSecret() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }
}

// MARK: - Types

enum AgentState {
    case unknown
    case notFound
    case detected
    case connected
    case unhealthy
    case error
    
    var displayName: String {
        switch self {
        case .unknown: return "Checking..."
        case .notFound: return "Not Installed"
        case .detected: return "Detected"
        case .connected: return "Connected"
        case .unhealthy: return "Unhealthy"
        case .error: return "Error"
        }
    }
    
    var iconName: String {
        switch self {
        case .unknown: return "ellipsis.circle"
        case .notFound: return "xmark.circle"
        case .detected: return "antenna.radiowaves.left.and.right"
        case .connected: return "checkmark.circle.fill"
        case .unhealthy: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

enum AgentManagerError: LocalizedError {
    case noActiveAccount
    case noAgentDetected
    case deploymentFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noActiveAccount: return "No active account"
        case .noAgentDetected: return "No agent detected on this panel"
        case .deploymentFailed(let msg): return "Deployment failed: \(msg)"
        }
    }
}
