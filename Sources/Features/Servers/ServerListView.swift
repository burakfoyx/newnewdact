import SwiftUI

class ServerListViewModel: ObservableObject {
    @Published var servers: [ServerAttributes] = []
    @Published var serverStates: [String: String] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadServers() async {
        await MainActor.run { isLoading = true }
        
        do {
            let fetchedServers = try await PterodactylClient.shared.fetchServers()
            await MainActor.run {
                self.servers = fetchedServers
                self.isLoading = false
            }
            // Fetch statuses after list is populated
            await fetchStatuses()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func fetchStatuses() async {
        await withTaskGroup(of: (String, String?).self) { group in
            for server in servers {
                group.addTask {
                    if let stats = try? await PterodactylClient.shared.fetchResources(serverId: server.identifier) {
                        return (server.uuid, stats.currentState)
                    }
                    return (server.uuid, nil)
                }
            }
            
            for await (uuid, state) in group {
                if let state = state {
                    await MainActor.run {
                        self.serverStates[uuid] = state
                    }
                }
            }
        }
    }
}

struct ServerListView: View {
    @StateObject private var viewModel = ServerListViewModel()
    
    var body: some View {
        ZStack {
            // Background
            LiquidBackgroundView()
            
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
                    LazyVStack(spacing: 20) {
                        ForEach(viewModel.servers, id: \.uuid) { server in
                            NavigationLink(destination: ServerDetailView(server: server)) {
                                ServerRow(server: server, state: viewModel.serverStates[server.uuid])
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingsView()) {
                     Image(systemName: "gearshape.fill")
                        .foregroundStyle(.white)
                }
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .background(Color.black) // Fallback
        .task {
            if viewModel.servers.isEmpty {
                await viewModel.loadServers()
            }
        }
        // Auto-refresh stats occasionally? 
        // For now, only on load.
    }
}

struct ServerRow: View {
    let server: ServerAttributes
    let state: String?
    
    var statusColor: Color {
        // Dynamic State
        if let state = state {
            switch state {
            case "running": return .green
            case "starting": return .yellow
            case "stopping": return .orange
            case "offline": return .gray
            default: return .black // Unknown
            }
        }
        
        // Static Fallbacks
        if server.isSuspended { return .orange }
        if server.isInstalling { return .blue }
        return .black // Default "Unknown" until fetched
    }

    var body: some View {
        HStack {
            // Status Indicator (Dot)
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.4), radius: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(server.node)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                
                HStack(spacing: 12) {
                    Label("\(server.limits.memory ?? 0)MB", systemImage: "memorychip")
                    Label("\(server.limits.disk ?? 0)MB", systemImage: "internaldrive")
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 4)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding()
        .background(
            LinearGradient(
                colors: [statusColor.opacity(0.25), statusColor.opacity(0.05)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
