import SwiftUI

class ServerListViewModel: ObservableObject {
    @Published var servers: [ServerAttributes] = []
    @Published var serverStats: [String: ServerStats] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentAccountId: UUID?
    
    func clear() {
        servers = []
        serverStats = [:]
        errorMessage = nil
    }
    
    func loadServers() async {
        await MainActor.run { 
            isLoading = true
            // Clear old servers before loading new ones
            servers = []
            serverStats = [:]
            errorMessage = nil
        }
        do {
            let fetchedServers = try await PterodactylClient.shared.fetchServers()
            await MainActor.run {
                self.servers = fetchedServers
                self.isLoading = false
            }
            await fetchStats()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func fetchStats() async {
        await withTaskGroup(of: (String, ServerStats?).self) { group in
            for server in servers {
                group.addTask {
                    if let stats = try? await PterodactylClient.shared.fetchResources(serverId: server.identifier) {
                        return (server.uuid, stats)
                    }
                    return (server.uuid, nil)
                }
            }
            
            for await (uuid, stats) in group {
                if let stats = stats {
                    await MainActor.run {
                        self.serverStats[uuid] = stats
                    }
                }
            }
        }
    }
}

struct ServerListView: View {
    @StateObject private var viewModel = ServerListViewModel()
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var showCreateSheet = false
    @State private var navigationPath = NavigationPath()
    
    private var hasAdminAccess: Bool {
        accountManager.activeAccount?.hasAdminAccess ?? false
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                
                if viewModel.isLoading {
                    ProgressView("Loading Servers...")
                        .tint(.white)
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Retry") {
                            Task { await viewModel.loadServers() }
                        }
                        .buttonStyle(LiquidButtonStyle())
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.servers, id: \.uuid) { server in
                                NavigationLink(destination: ServerDetailView(server: server)) {
                                    ServerRow(server: server, stats: viewModel.serverStats[server.uuid])
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                        .padding(.bottom, hasAdminAccess ? 80 : 0) // Make room for FAB
                    }
                    .scrollContentBackground(.hidden)
                }
                
                // Floating Action Button for Admin Users
                if hasAdminAccess && !viewModel.isLoading {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: { showCreateSheet = true }) {
                                Image(systemName: "plus")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 56, height: 56)
                                    .glassEffect(.clear.interactive(), in: Circle())
                                    .shadow(color: .purple.opacity(0.5), radius: 10)
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Servers")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task {
            // Always load on appear
            await viewModel.loadServers()
            viewModel.currentAccountId = accountManager.activeAccount?.id
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateServerView()
        }
        .onChange(of: showCreateSheet) { _, isPresented in
            if !isPresented {
                // Refresh servers after creating
                Task { await viewModel.loadServers() }
            }
        }
        .onChange(of: accountManager.activeAccount?.id) { oldId, newId in
            // Account changed - reset navigation and reload servers
            if oldId != newId {
                navigationPath = NavigationPath() // Pop all detail views
                viewModel.clear()
                Task { await viewModel.loadServers() }
                viewModel.currentAccountId = newId
            }
        }
    }
}

struct ServerRow: View {
    let server: ServerAttributes
    let stats: ServerStats?
    
    var statusColor: Color {
        // Dynamic State
        if let state = stats?.currentState {
            switch state {
            case "running": return .green
            case "starting": return .yellow
            case "stopping": return .orange
            case "offline": return .gray
            case "installing": return .blue
            case "suspended": return .orange
            default: return .black
            }
        }
        
        // Static Fallbacks
        if server.isSuspended { return .orange }
        if server.isInstalling { return .blue }
        return .black
    }
    
    var memoryUsage: String {
        let usedMB = Double(stats?.resources.memoryBytes ?? 0) / 1024 / 1024
        let limitMB = Double(server.limits.memory ?? 0)
        return String(format: "%.0f / %.0f MB", usedMB, limitMB)
    }
    
    var cpuUsage: String {
        let used = stats?.resources.cpuAbsolute ?? 0
        let limit = Double(server.limits.cpu ?? 0)
        return String(format: "%.1f%% / %.0f%%", used, limit)
    }

    var displayIP: String {
        if let allocations = server.relationships?.allocations?.data {
            if let defaultAlloc = allocations.first(where: { $0.attributes.isDefault }) {
                return "\(defaultAlloc.attributes.ip):\(defaultAlloc.attributes.port)"
            }
        }
        return server.sftpDetails.ip
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                // Server Name
                Text(server.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                
                // IP Address
                HStack(spacing: 4) {
                     Image(systemName: "network")
                        .font(.caption2)
                     Text(displayIP) 
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.6))
                
                // Resources
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                        Text(cpuUsage)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "memorychip")
                        Text(memoryUsage)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
            
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Small status indicator on left edge only (status color -> transparent)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [statusColor.opacity(0.4), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 60) // Only 60pt wide on the left
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16,
                        bottomLeadingRadius: 16,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                )
                .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
