import SwiftUI
import SwiftData

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
    @Query private var customizations: [ServerCustomization]
    @State private var showCreateSheet = false
    @State private var showGroupsSheet = false
    @State private var serverToCustomize: ServerAttributes?
    @State private var navigationPath = NavigationPath()
    @Environment(\.modelContext) private var modelContext
    
    private var hasAdminAccess: Bool {
        accountManager.activeAccount?.hasAdminAccess ?? false
    }
    
    // Sort servers with favorites at top
    private var sortedServers: [ServerAttributes] {
        let favoriteIds = Set(customizations.filter { $0.isFavorite }.map { $0.serverId })
        return viewModel.servers.sorted { server1, server2 in
            let isFav1 = favoriteIds.contains(server1.identifier)
            let isFav2 = favoriteIds.contains(server2.identifier)
            if isFav1 != isFav2 { return isFav1 }
            return server1.name < server2.name
        }
    }
    
    private func customization(for serverId: String) -> ServerCustomization? {
        customizations.first { $0.serverId == serverId }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {

                
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                content
            }
            .background(Color.clear)
            .navigationTitle("Servers")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar { toolbarContent }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .task {
            await viewModel.loadServers()
            viewModel.currentAccountId = accountManager.activeAccount?.id
        }
        .sheet(isPresented: $showCreateSheet) { CreateServerView() }
        .sheet(isPresented: $showGroupsSheet) { ServerGroupsView() }
        .sheet(item: $serverToCustomize) { server in ServerCustomizationSheet(server: server) }
        .onChange(of: showCreateSheet) { _, isPresented in
            if !isPresented { Task { await viewModel.loadServers() } }
        }
        .onChange(of: accountManager.activeAccount?.id) { oldId, newId in
            if oldId != newId {
                navigationPath = NavigationPath()
                viewModel.clear()
                Task { await viewModel.loadServers() }
                viewModel.currentAccountId = newId
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Loading Servers...")
                .tint(.white)
        } else if let error = viewModel.errorMessage {
            errorView(error)
        } else {
            successContent
        }
    }
    
    private var successContent: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sortedServers, id: \.uuid) { server in
                        serverRowLink(for: server)
                    }
                }
                .padding()
                .padding(.bottom, hasAdminAccess ? 80 : 0)
            }
            .scrollContentBackground(.hidden)
            
            if hasAdminAccess {
                floatingActionButton
            }
        }
    }
    
    private func errorView(_ error: String) -> some View {
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
    }
    
    private func serverRowLink(for server: ServerAttributes) -> some View {
        NavigationLink(destination: ServerDetailView(server: server)) {
            ServerRow(
                server: server,
                stats: viewModel.serverStats[server.uuid],
                customization: customization(for: server.identifier)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            serverContextMenu(for: server)
        }
    }
    
    @ViewBuilder
    private func serverContextMenu(for server: ServerAttributes) -> some View {
        Button("Customize", systemImage: "paintbrush") {
            serverToCustomize = server
        }
        
        if let custom = customization(for: server.identifier), custom.isFavorite {
            Button("Remove from Favorites", systemImage: "star.slash") {
                custom.isFavorite = false
            }
        } else {
            Button("Add to Favorites", systemImage: "star.fill") {
                toggleFavorite(for: server)
            }
        }
    }
    
    private var floatingActionButton: some View {
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
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            NotificationBellButton()
        }
        
        ToolbarItem(placement: .primaryAction) {
            Button {
                showGroupsSheet = true
            } label: {
                Image(systemName: "folder.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }
        }
    }
    
    private func toggleFavorite(for server: ServerAttributes) {
        if let existing = customization(for: server.identifier) {
            existing.isFavorite.toggle()
        } else {
            let newCustomization = ServerCustomization(serverId: server.identifier)
            newCustomization.isFavorite = true
            modelContext.insert(newCustomization)
        }
    }
}

// MARK: - Server Row

struct ServerRow: View {
    let server: ServerAttributes
    let stats: ServerStats?
    var customization: ServerCustomization? = nil
    
    // Extracted Display Logic
    private var displayName: String { customization?.customName ?? server.name }
    private var isFavorite: Bool { customization?.isFavorite ?? false }
    
    // Status Logic
    private var statusColor: Color {
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
        if server.isSuspended { return .orange }
        if server.isInstalling { return .blue }
        return .black
    }
    
    // Resource Strings
    private var memoryUsage: String {
        let usedMB = Double(stats?.resources.memoryBytes ?? 0) / 1024 / 1024
        let limitMB = Double(server.limits.memory ?? 0)
        return String(format: "%.0f / %.0f MB", usedMB, limitMB)
    }
    
    private var cpuUsage: String {
        let used = stats?.resources.cpuAbsolute ?? 0
        let limit = Double(server.limits.cpu ?? 0)
        return String(format: "%.1f%% / %.0f%%", used, limit)
    }

    private var displayIP: String {
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
                // Name Row
                HStack(spacing: 6) {
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    Text(displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                
                // IP Row
                HStack(spacing: 4) {
                     Image(systemName: "network")
                        .font(.caption2)
                     Text(displayIP) 
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.6))
                
                // Resources Row
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
        .overlay(alignment: .leading) {
            ServerStatusIndicator(color: statusColor)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ServerStatusIndicator: View {
    let color: Color
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.4), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 60)
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
}
