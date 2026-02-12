import SwiftUI

/// Agent settings and management view.
/// Shows agent health, controls, log viewer, and uninstall option.
struct AgentSettingsView: View {
    @StateObject private var agentManager = AgentManager.shared
    @ObservedObject private var accountManager = AccountManager.shared
    
    @State private var showSetup = false
    @State private var showLogs = false
    @State private var logContent = ""
    @State private var isLoadingLogs = false
    @State private var showUninstallConfirm = false
    
    var body: some View {
        Group {
            statusSection
            
            if agentManager.agentState == .connected || agentManager.agentState == .unhealthy {
                healthSection
                controlsSection
                logsSection
                dangerSection
            }
            
            if agentManager.agentState == .notFound || agentManager.agentState == .unknown {
                setupSection
            }
        }
        .sheet(isPresented: $showSetup) {
            AgentSetupView()
        }
        .sheet(isPresented: $showLogs) {
            logViewerSheet
        }
        .alert("Remove Agent", isPresented: $showUninstallConfirm) {
            Button("Remove", role: .destructive) {
                disconnectAgent()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will disconnect your account from the agent. The agent server will not be deleted from the panel.")
        }
        .task {
            if agentManager.agentState == .unknown {
                await agentManager.detectAgent()
            }
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(statusGradient)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: agentManager.agentState.iconName)
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Agent Status")
                        .font(.headline)
                    Text(agentManager.agentState.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if agentManager.isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Self-Hosted Agent")
        }
    }
    
    private var statusGradient: LinearGradient {
        switch agentManager.agentState {
        case .connected:
            return LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .unhealthy:
            return LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .detected:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    // MARK: - Health Section
    
    private var healthSection: some View {
        Section("Agent Health") {
            if let status = agentManager.agentStatus {
                infoRow(label: "Version", value: status.agentVersion)
                infoRow(label: "Uptime", value: status.uptimeFormatted)
                infoRow(label: "Last Sample", value: formatDate(status.lastSampleAt))
                infoRow(label: "Servers Monitored", value: "\(status.serversMonitored)")
                infoRow(label: "Active Alerts", value: "\(status.activeAlerts)")
                infoRow(label: "Active Automations", value: "\(status.activeAutomations)")
                infoRow(label: "Users", value: "\(status.usersCount)")
                
                if let dbSize = status.dbSizeBytes {
                    infoRow(label: "Database Size", value: formatBytes(dbSize))
                }
                
                if let errors = status.errors, !errors.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Errors")
                            .font(.caption.bold())
                            .foregroundStyle(.red)
                        ForEach(errors, id: \.self) { error in
                            Text("• \(error)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Loading...")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Controls
    
    private var controlsSection: some View {
        Section("Controls") {
            Button {
                Task { await agentManager.refreshStatus() }
            } label: {
                Label("Refresh Status", systemImage: "arrow.clockwise")
            }
            
            if let serverID = accountManager.activeAccount?.agentServerIdentifier {
                Button {
                    Task {
                        try? await PterodactylClient.shared.sendPowerSignal(serverId: serverID, signal: "restart")
                    }
                } label: {
                    Label("Restart Agent", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }
    
    // MARK: - Logs
    
    private var logsSection: some View {
        Section("Logs") {
            Button {
                loadLogs()
            } label: {
                Label("View Agent Logs", systemImage: "doc.text")
            }
        }
    }
    
    private var logViewerSheet: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    if isLoadingLogs {
                        ProgressView("Loading logs...")
                            .padding()
                    } else if logContent.isEmpty {
                        Text("No logs available")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        Text(logContent)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .navigationTitle("Agent Logs")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showLogs = false }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        loadLogs()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
    
    // MARK: - Danger Zone
    
    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showUninstallConfirm = true
            } label: {
                Label("Disconnect from Agent", systemImage: "xmark.circle")
            }
        } footer: {
            Text("This removes your account from the agent. The agent server on the panel will not be deleted.")
                .font(.caption2)
        }
    }
    
    // MARK: - Setup Prompt
    
    private var setupSection: some View {
        Section {
            Button {
                showSetup = true
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Set Up Agent")
                            .font(.headline)
                        Text("Enable push notifications & automations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Self-Hosted Agent")
        } footer: {
            Text("The agent runs on your panel — no third-party servers, no data leaves your infrastructure.")
                .font(.caption2)
        }
    }
    
    // MARK: - Helpers
    
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
    
    private func formatDate(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return iso }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func loadLogs() {
        isLoadingLogs = true
        showLogs = true
        Task {
            do {
                logContent = try await agentManager.readLogs()
            } catch {
                logContent = "Failed to load logs: \(error.localizedDescription)"
            }
            isLoadingLogs = false
        }
    }
    
    private func disconnectAgent() {
        guard var account = accountManager.activeAccount else { return }
        account.agentServerIdentifier = nil
        account.agentSecret = nil
        account.agentConnected = false
        accountManager.updateAccount(account)
        agentManager.agentState = .notFound
        agentManager.agentStatus = nil
    }
}
