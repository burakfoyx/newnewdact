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

enum ServerViewMode: String {
    case list
    case category
}

struct ServerListView: View {
    @StateObject private var viewModel = ServerListViewModel()
    @ObservedObject private var accountManager = AccountManager.shared
    
    // Data Models
    @Query private var customizations: [ServerCustomization]
    @Query(sort: \ServerGroup.sortOrder) private var groups: [ServerGroup]
    
    // View State
    @AppStorage("serverViewMode") private var viewMode: ServerViewMode = .list
    @State private var showCreateSheet = false
    @State private var showGroupsSheet = false
    @State private var serverToCustomize: ServerAttributes?
    @State private var navigationPath = NavigationPath()
    @State private var isEditing = false
    
    @Environment(\.modelContext) private var modelContext
    
    private var hasAdminAccess: Bool {
        accountManager.activeAccount?.hasAdminAccess ?? false
    }
    
    // Unified Sorting Logic
    private var sortedServers: [ServerAttributes] {
        let pinnedIds = Set(customizations.filter { $0.isPinned }.map { $0.serverId })
        let sortOrders = Dictionary(uniqueKeysWithValues: customizations.map { ($0.serverId, $0.sortOrder) })
        
        return viewModel.servers.sorted { s1, s2 in
            // 1. Pinned
            let isPinned1 = pinnedIds.contains(s1.identifier)
            let isPinned2 = pinnedIds.contains(s2.identifier)
            if isPinned1 != isPinned2 { return isPinned1 }
            
            // 2. Custom Sort Order
            let order1 = sortOrders[s1.identifier] ?? 0
            let order2 = sortOrders[s2.identifier] ?? 0
            if order1 != order2 { return order1 < order2 }
            
            // 3. Name
            return s1.name < s2.name
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
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .task {
            // Cleanup duplicates for safety
            cleanupCustomizations()
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
    
    // Safety cleanup
    private func cleanupCustomizations() {
        // Implementation left minimal - SwiftData usually handles uniqueness constraints
        // but explicit cleanup can prevent crashes if logic was changed
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
            List {
                if viewMode == .list {
                    // MARK: - List View
                    ForEach(sortedServers, id: \.uuid) { server in
                        serverRowLink(for: server)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onMove(perform: moveServers)
                    
                } else {
                    // MARK: - Category View
                    
                    // 1. Favorites Category
                    let favorites = viewModel.servers.filter { s in
                        customization(for: s.identifier)?.isFavorite ?? false
                    }
                    
                    if !favorites.isEmpty {
                        Section(header: categoryHeader("Favorites", icon: "star.fill", color: .yellow)) {
                            ForEach(favorites, id: \.uuid) { server in
                                serverRowLink(for: server)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                    }
                    
                    // 2. User Groups
                    ForEach(groups) { group in
                        let groupServers = viewModel.servers.filter { group.serverIds.contains($0.identifier) }
                        if !groupServers.isEmpty {
                            Section(header: categoryHeader(group.name, icon: group.icon, color: group.colorHex.asColor)) {
                                ForEach(groupServers, id: \.uuid) { server in
                                    serverRowLink(for: server)
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                }
                            }
                        }
                    }
                    .onMove(perform: moveGroups)
                    
                    // 3. Uncategorized (Everything else)
                    let categorizedIds = Set(groups.flatMap { $0.serverIds })
                    // Note: Servers can be in favorites AND groups.
                    // "Uncategorized" usually means not in any USER group.
                    let uncategorized = viewModel.servers.filter { !categorizedIds.contains($0.identifier) }
                    
                    if !uncategorized.isEmpty {
                        Section(header: categoryHeader("Servers", icon: "server.rack", color: .secondary)) {
                            ForEach(uncategorized, id: \.uuid) { server in
                                serverRowLink(for: server)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            
            if hasAdminAccess && !isEditing {
                floatingActionButton
            }
        }
    }
    
    private func categoryHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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
        ZStack {
            NavigationLink(destination: ServerDetailView(server: server)) {
                EmptyView()
            }
            .opacity(0)
            
            ServerRow(
                server: server,
                stats: viewModel.serverStats[server.uuid],
                customization: customization(for: server.identifier)
            )
            .contextMenu {
                // Pin Action
                Button {
                    togglePin(for: server)
                } label: {
                    let isPinned = customization(for: server.identifier)?.isPinned ?? false
                    Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
                }
                
                // Favorite Action
                Button {
                    toggleFavorite(for: server)
                } label: {
                    let isFavorite = customization(for: server.identifier)?.isFavorite ?? false
                    Label(isFavorite ? "Unfavorite" : "Favorite", systemImage: isFavorite ? "star.slash" : "star")
                }
                
                // Group Action
                Menu {
                    if groups.isEmpty {
                        Button("No Groups Created", action: {})
                            .disabled(true)
                    } else {
                        ForEach(groups) { group in
                            Button {
                                toggleGroupMembership(server: server, group: group)
                            } label: {
                                let isInGroup = group.serverIds.contains(server.identifier)
                                Label(group.name, systemImage: isInGroup ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                } label: {
                    Label("Add to Group", systemImage: "folder")
                }
                
                // Edit
                Button {
                    serverToCustomize = server
                } label: {
                    Label("Customize", systemImage: "paintbrush")
                }
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
                .padding(.trailing, 16)
                .padding(.bottom, 30) // Extra bottom padding for safe area
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            NotificationBellButton()
        }
        
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 8) {
                // Edit / Done Button
                Button {
                    withAnimation { isEditing.toggle() }
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(.clear, in: Capsule())
                }
                
                // Group Management
                if !isEditing {
                    Button {
                        showGroupsSheet = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(10)
                            .glassEffect(.clear, in: Circle())
                    }
                    
                    // View Toggle
                    Button {
                        withAnimation {
                            viewMode = (viewMode == .list) ? .category : .list
                        }
                    } label: {
                        Image(systemName: viewMode == .list ? "square.grid.2x2" : "list.bullet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(10)
                            .glassEffect(.clear, in: Circle())
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleGroupMembership(server: ServerAttributes, group: ServerGroup) {
        if let index = group.serverIds.firstIndex(of: server.identifier) {
            group.serverIds.remove(at: index)
        } else {
            group.serverIds.append(server.identifier)
        }
        // Save handled by SwiftData autosave, but explicit can be safer
        // try? modelContext.save() 
    }
    
    private func moveServers(from source: IndexSet, to destination: Int) {
        // Moves are complex with mixed pinned/unpinned. 
        // Simple approach: reassign sortOrder for ALL servers based on the new list order.
        var reorderedServers = sortedServers
        reorderedServers.move(fromOffsets: source, toOffset: destination)
        
        // Update sort orders
        for (index, server) in reorderedServers.enumerated() {
            if let custom = customization(for: server.identifier) {
                custom.sortOrder = index
            } else {
                let newCustom = ServerCustomization(serverId: server.identifier)
                newCustom.sortOrder = index
                modelContext.insert(newCustom)
            }
        }
    }
    
    private func moveGroups(from source: IndexSet, to destination: Int) {
        var reorderedGroups = groups
        reorderedGroups.move(fromOffsets: source, toOffset: destination)
        
        for (index, group) in reorderedGroups.enumerated() {
            group.sortOrder = index
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
    
    private func togglePin(for server: ServerAttributes) {
        if let existing = customization(for: server.identifier) {
            existing.isPinned.toggle()
        } else {
            let newCustomization = ServerCustomization(serverId: server.identifier)
            newCustomization.isPinned = true
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
    private var isPinned: Bool { customization?.isPinned ?? false }
    
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
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .rotationEffect(.degrees(45))
                    }
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
