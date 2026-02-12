import SwiftUI

/// Agent setup/onboarding view.
/// Shows deploy or connect flow depending on agent state.
struct AgentSetupView: View {
    @StateObject private var agentManager = AgentManager.shared
    @ObservedObject private var accountManager = AccountManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var secretInput = ""
    @State private var showDeployFlow = false
    @State private var isDeploying = false
    @State private var deployError: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        headerCard
                        statusCard
                        actionSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Agent Setup")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await agentManager.detectAgent()
            }
        }
    }
    
    // MARK: - Header
    
    private var headerCard: some View {
        LiquidGlassCard {
            VStack(spacing: 12) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 44))
                    .foregroundStyle(.cyan)
                    .symbolEffect(.variableColor.iterative.reversing)
                
                Text("XYIDactyl Agent")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                
                Text("Self-hosted push notifications, monitoring, and automations — running on your panel with zero inbound networking.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Status
    
    private var statusCard: some View {
        LiquidGlassCard {
            HStack(spacing: 16) {
                Image(systemName: agentManager.agentState.iconName)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Agent Status")
                        .font(.headline)
                    Text(agentManager.agentState.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if agentManager.isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var statusColor: Color {
        switch agentManager.agentState {
        case .connected: return .green
        case .detected: return .blue
        case .unhealthy: return .orange
        case .error: return .red
        case .notFound: return .gray
        case .unknown: return .gray
        }
    }
    
    // MARK: - Actions
    
    @ViewBuilder
    private var actionSection: some View {
        switch agentManager.agentState {
        case .notFound:
            notFoundSection
        case .detected:
            connectSection
        case .connected:
            connectedSection
        case .error:
            errorSection
        default:
            EmptyView()
        }
    }
    
    private var notFoundSection: some View {
        LiquidGlassCard {
            VStack(spacing: 16) {
                Image(systemName: "plus.circle")
                    .font(.title)
                    .foregroundStyle(.blue)
                
                Text("No agent found on this panel")
                    .font(.headline)
                
                Text("Deploy an agent server to enable push notifications, background monitoring, and automations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                if accountManager.activeAccount?.hasAdminAccess == true {
                    Button {
                        showDeployFlow = true
                    } label: {
                        HStack {
                            Image(systemName: "server.rack")
                            Text("Deploy Agent")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.liquidGlass)
                } else {
                    Text("Admin API access required to deploy the agent. Ask your panel admin to set up the agent.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showDeployFlow) {
            AgentDeploySheet()
        }
    }
    
    private var connectSection: some View {
        LiquidGlassCard {
            VStack(spacing: 16) {
                Image(systemName: "link.badge.plus")
                    .font(.title)
                    .foregroundStyle(.green)
                
                Text("Agent detected!")
                    .font(.headline)
                
                Text("Enter the agent secret to connect. This was generated during deployment.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                SecureField("Agent Secret", text: $secretInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                Button {
                    Task {
                        do {
                            try await agentManager.connectUser(agentSecret: secretInput)
                        } catch {
                            deployError = error.localizedDescription
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "link")
                        Text("Connect")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.liquidGlass)
                .disabled(secretInput.isEmpty)
                
                if let error = deployError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var connectedSection: some View {
        LiquidGlassCard {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                
                Text("Connected!")
                    .font(.headline)
                
                Text("Your agent is running. Manage it from Settings → Agent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Done") { dismiss() }
                    .buttonStyle(.liquidGlass)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var errorSection: some View {
        LiquidGlassCard {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(.red)
                
                Text(agentManager.errorMessage ?? "Unknown error")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    Task { await agentManager.detectAgent() }
                } label: {
                    Text("Retry")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.liquidGlass)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Deploy Sheet

struct AgentDeploySheet: View {
    @StateObject private var agentManager = AgentManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedNodeId: Int? = nil
    @State private var nodes: [NodeAttributes] = []
    @State private var isDeploying = false
    @State private var deployError: String? = nil
    @State private var deploySuccess = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        LiquidGlassCard {
                            VStack(spacing: 12) {
                                Text("Deploy Agent")
                                    .font(.title2.bold())
                                
                                Text("This will create a lightweight server on your panel running the XYIDactyl monitoring agent.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                resourceInfoCard
                            }
                            .frame(maxWidth: .infinity)
                        }
                        
                        if !nodes.isEmpty {
                            LiquidGlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Select Node")
                                        .font(.headline)
                                    
                                    ForEach(nodes, id: \.id) { node in
                                        Button {
                                            selectedNodeId = node.id
                                        } label: {
                                            HStack {
                                                Image(systemName: selectedNodeId == node.id ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(selectedNodeId == node.id ? .blue : .secondary)
                                                Text(node.name)
                                                    .foregroundStyle(.primary)
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        if let error = deployError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                        }
                        
                        if deploySuccess {
                            LiquidGlassCard {
                                VStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.green)
                                    Text("Agent deployed successfully!")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        
                        if !deploySuccess {
                            Button {
                                deployAgent()
                            } label: {
                                HStack {
                                    if isDeploying {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "arrow.up.circle.fill")
                                    }
                                    Text(isDeploying ? "Deploying..." : "Deploy")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.liquidGlass)
                            .disabled(selectedNodeId == nil || isDeploying)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Deploy")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await loadNodes()
            }
        }
    }
    
    private var resourceInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            resourceRow(label: "Memory", value: "256 MB")
            resourceRow(label: "Disk", value: "1 GB")
            resourceRow(label: "CPU", value: "50%")
            resourceRow(label: "Ports", value: "None (outbound only)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func resourceRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
    }
    
    private func loadNodes() async {
        do {
            nodes = try await PterodactylClient.shared.fetchNodes()
            if nodes.count == 1 {
                selectedNodeId = nodes.first?.id
            }
        } catch {
            deployError = "Failed to load nodes: \(error.localizedDescription)"
        }
    }
    
    private func deployAgent() {
        guard let nodeId = selectedNodeId else { return }
        isDeploying = true
        deployError = nil
        
        Task {
            do {
                // Get allocation and user info
                let allocations = try await PterodactylClient.shared.fetchApplicationAllocations(nodeId: nodeId)
                guard let allocation = allocations.first else {
                    deployError = "No available allocations on this node"
                    isDeploying = false
                    return
                }
                
                var userId: Int = 0
                
                do {
                    let userInfo = try await PterodactylClient.shared.fetchCurrentUser()
                    userId = userInfo.id
                } catch {
                    // Fallback: If using an Application Key, Client API (fetchCurrentUser) fails.
                    // Try to fetch users via Application API and use the first root admin or user.
                    let users = try await PterodactylClient.shared.fetchApplicationUsers()
                    if let targetUser = users.first(where: { $0.rootAdmin }) ?? users.first {
                        userId = targetUser.id
                    } else {
                        throw error // Rethrow original error if we can't find any users
                    }
                }
                
                try await agentManager.deployAgent(
                    nodeId: nodeId,
                    allocationId: allocation.id,
                    eggId: 1, // Agent egg — should be found dynamically in production
                    userId: userId
                )
                
                deploySuccess = true
            } catch {
                deployError = error.localizedDescription
            }
            isDeploying = false
        }
    }
}
