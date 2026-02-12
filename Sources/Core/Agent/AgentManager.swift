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
    
    // MARK: - Agent Deployment
    
    /// Deploys a new XYIDactyl Agent server on the panel.
    /// Requires admin (Application API) access.
    @MainActor
    func deployAgent(nodeId: Int, allocationId: Int, userId: Int) async throws {
        guard let account = AccountManager.shared.activeAccount else {
            throw AgentManagerError.noActiveAccount
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // Find or Create the Agent Egg
        let (eggId, dockerImage, startup) = try await ensureAgentEgg()
        
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
            "LOG_LEVEL": "info",
            "CONTROL_FILE_PATH": "./control/control.json"
        ]
        
        // ... (rest of function)
        
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
            dockerImage: dockerImage,
            startup: startup,
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
        do {
            let servers = try await client.fetchServers()
            let serverIDs = servers.map { $0.identifier }
            
            try await self.fileManager?.upsertUser(
                userUUID: account.id.uuidString,
                apiKey: account.apiKey,
                agentSecret: agentSecretValue,
                isAdmin: account.hasAdminAccess,
                allowedServers: serverIDs,
                deviceToken: nil 
            )
        } catch {
            print("Warning: Failed to register user in control.json immediately after deploy: \(error)")
        }
        
        agentState = .connected
    }
    
    /// Ensures the XYIDactyl Nest and Egg exist, creating them if necessary.
    private func ensureAgentEgg() async throws -> (Int, String, String) {
        // 1. Ensure Nest
        let nests = try await client.fetchNests()
        var nestId = nests.first(where: { $0.name == "XYIDactyl" })?.id
        
        if nestId == nil {
            do {
                let newNest = try await client.createNest(
                    name: "XYIDactyl",
                    description: "Nests for XYIDactyl App",
                    author: "support@xyidactyl.com"
                )
                nestId = newNest.id
            } catch {
                print("Failed to create XYIDactyl nest: \(error). Trying fallback to 'Generic'.")
                // Fallback: Use "Generic" nest if available (standard Pterodactyl nest)
                if let genericNest = nests.first(where: { $0.name == "Generic" }) {
                     nestId = genericNest.id
                } else {
                     // If we can't create and can't find fallback, fail.
                     throw AgentManagerError.deploymentFailed("Failed to create 'XYIDactyl' nest and could not find 'Generic' nest fallback. Error: \(error.localizedDescription)")
                }
            }
        }
        
        guard let finalNestId = nestId else {
            throw AgentManagerError.deploymentFailed("Failed to find or create Nest")
        }
        
        // 2. Ensure Egg
        let eggs = try await client.fetchEggs(nestId: finalNestId)
        var egg = eggs.first(where: { $0.name == AgentEggDefinition.name })
        
        if egg == nil {
            let scripts: [String: Any] = [
                "installation": [
                    "script": AgentEggDefinition.script,
                    "container": "alpine:3.19",
                    "entrypoint": "ash"
                ]
            ]
            
            let newEgg = try await client.createEgg(
                nestId: finalNestId,
                name: AgentEggDefinition.name,
                description: AgentEggDefinition.description,
                dockerImage: AgentEggDefinition.dockerImage,
                startup: AgentEggDefinition.startup,
                config: AgentEggDefinition.config,
                scripts: scripts,
                author: "support@xyidactyl.com"
            )
            egg = newEgg
        }
        
        guard let finalEgg = egg else {
            throw AgentManagerError.deploymentFailed("Failed to find or create Egg")
        }
        
        // 3. Ensure Variables
        // Note: fetchEggs includes variables if requested, PterodactylClient.fetchEggs does include=variables
        let existingVars = finalEgg.relationships?.variables?.data.map { $0.attributes.envVariable } ?? []
        
        for variableDef in AgentEggDefinition.variables {
            guard let envVar = variableDef["env_variable"] as? String else { continue }
            
            if !existingVars.contains(envVar) {
                do {
                    try await client.createEggVariable(
                        nestId: finalNestId,
                        eggId: finalEgg.id,
                        name: variableDef["name"] as? String ?? "",
                        description: variableDef["description"] as? String ?? "",
                        envVariable: envVar,
                        defaultValue: variableDef["default_value"] as? String ?? "",
                        rules: variableDef["rules"] as? String ?? "",
                        userViewable: variableDef["user_viewable"] as? Bool ?? true,
                        userEditable: variableDef["user_editable"] as? Bool ?? true
                    )
                } catch {
                    print("⚠️ Failed to create variable \(envVar): \(error.localizedDescription) (it might already exist)")
                    // Continue to next variable
                }
            }
        }
        
        return (finalEgg.id, AgentEggDefinition.dockerImage, AgentEggDefinition.startup)
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
        print("🔍 Fetching accessible servers for agent...")
        // Start with Client API (preferred)
        var serverIDs: [String] = []
        
        do {
            let servers = try await client.fetchServers()
            serverIDs = servers.map { $0.identifier }
            print("🔍 Found \(serverIDs.count) servers via Client API")
        } catch {
            print("⚠️ Client API fetch failed: \(error)")
        }
        
        // Fallback to Application API if empty and user is admin
        if serverIDs.isEmpty && account.hasAdminAccess {
            print("⚠️ No servers found via Client API. Attempting Application API (Admin)...")
            do {
                let appServers = try await client.fetchApplicationServers()
                serverIDs = appServers.map { $0.identifier }
                print("🔍 Found \(serverIDs.count) servers via Application API")
            } catch {
                print("❌ Application API fetch failed: \(error)")
            }
        }
        
        print("🔍 Final Server List (\(serverIDs.count)): \(serverIDs)")
        
        if serverIDs.isEmpty {
            print("⚠️ Warning: No servers found for this user. Agent will monitor 0 servers.")
            if !account.hasAdminAccess {
                print("💡 Hint: If you are an admin and want to monitor all servers, please log in with an Application API Key.")
            }
        }
        
        // Register in control.json
        print("📝 Updating control.json with user \(account.id.uuidString)...")
        try await fileManager?.upsertUser(
            userUUID: account.id.uuidString,
            apiKey: account.apiKey,
            agentSecret: agentSecret,
            isAdmin: account.hasAdminAccess,
            allowedServers: serverIDs,
            deviceToken: nil
        )
        print("✅ User registered in control.json")
        
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
            
            // Only mark as connected/unhealthy if we have the secret locally.
            // Otherwise, we are just detecting an existing agent.
            if agentSecret != nil {
                agentState = agentStatus?.isHealthy == true ? .connected : .unhealthy
            } else {
                agentState = .detected
            }
        } catch {
            // Status file may not exist yet if agent just started, or we can't reach it
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
