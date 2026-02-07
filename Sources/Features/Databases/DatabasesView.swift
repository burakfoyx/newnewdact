import SwiftUI

@MainActor
class DatabasesViewModel: ObservableObject {
    @Published var databases: [DatabaseAttributes] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func fetch(serverId: String) async {
        isLoading = true
        do {
            databases = try await PterodactylClient.shared.fetchDatabases(serverId: serverId)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func delete(serverId: String, databaseId: String) async {
        // Stub - API method may not exist yet
    }
    
    func resetPassword(serverId: String, databaseId: String) async {
        // Stub - API method may not exist yet
    }
}

struct DatabasesView: View {
    @StateObject private var viewModel = DatabasesViewModel()
    
    let serverId: String
    let serverName: String
    let statusState: String
    // @Binding var selectedTab: ServerTab // Removed
    // let onBack: () -> Void // Removed
    // let onPowerAction: (String) -> Void // Removed
    var stats: WebsocketResponse.Stats?
    var limits: ServerLimits?
    
    // Params removed: selectedTab, onBack, onPowerAction
    
    @State private var showingCreate = false
    
    init(serverId: String, serverName: String, statusState: String, stats: WebsocketResponse.Stats? = nil, limits: ServerLimits? = nil) {
        self.serverId = serverId
        self.serverName = serverName
        self.statusState = statusState
        // self._selectedTab = selectedTab // Removed
        // self.onBack = onBack // Removed
        // self.onPowerAction = onPowerAction // Removed
        self.stats = stats
        self.limits = limits
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                 // Header Hoisted
                
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                        .padding(.top, 40)
                } else if let error = viewModel.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding()
                } else if viewModel.databases.isEmpty {
                    ContentUnavailableView(
                        "No Databases",
                        systemImage: "cylinder.split.1x2",
                        description: Text("Create a database for your server.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.databases, id: \.id) { database in
                            LiquidGlassCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "cylinder.fill")
                                            .foregroundStyle(.blue)
                                        Text(database.name)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Spacer()
                                    }
                                    
                                    Divider().background(Color.white.opacity(0.1))
                                    
                                    HStack {
                                        Label(database.host.address + ":" + String(database.host.port), systemImage: "network")
                                        Spacer()
                                        Label(database.username, systemImage: "person.circle")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(serverId: serverId, databaseId: database.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    Task { await viewModel.resetPassword(serverId: serverId, databaseId: database.id) }
                                } label: {
                                    Label("Reset Password", systemImage: "key")
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 20) // Space for tab bar
        }
        .task {
            // Fetch if empty
            if viewModel.databases.isEmpty {
                await viewModel.fetch(serverId: serverId)
            }
        }
        .refreshable {
            await viewModel.fetch(serverId: serverId)
        }
    }
}
