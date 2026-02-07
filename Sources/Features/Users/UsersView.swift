import SwiftUI

@MainActor
class UsersViewModel: ObservableObject {
    @Published var users: [SubuserAttributes] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func fetch(serverId: String) async {
        isLoading = true
        do {
            users = try await PterodactylClient.shared.fetchUsers(serverId: serverId)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func delete(serverId: String, userUuid: String) async {
        isLoading = true
        // Stub - PterodactylClient.deleteSubuser may not exist yet
        users.removeAll { $0.uuid == userUuid }
        isLoading = false
    }
}

struct UsersView: View {
    @StateObject private var viewModel = UsersViewModel()
    
    let serverId: String
    let serverName: String
    let statusState: String
    var stats: WebsocketResponse.Stats?
    var limits: ServerLimits?
    
    @State private var showingCreate = false
    
    init(serverId: String, serverName: String, statusState: String, stats: WebsocketResponse.Stats? = nil, limits: ServerLimits? = nil) {
        self.serverId = serverId
        self.serverName = serverName
        self.statusState = statusState
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
                } else if viewModel.users.isEmpty {
                    ContentUnavailableView(
                        "No Users",
                        systemImage: "person.3.fill",
                        description: Text("Create subusers to manage your server.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.users, id: \.uuid) { user in
                            LiquidGlassCard {
                                HStack(spacing: 16) {
                                    // Avatar placeholder
                                    Circle()
                                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text(String(user.email.prefix(1)).uppercased())
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.username)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        
                                        Text(user.email)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    if user.twoFactorEnabled {
                                        Image(systemName: "lock.shield.fill")
                                            .foregroundStyle(.green)
                                            .font(.title3)
                                    }
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await viewModel.delete(serverId: serverId, userUuid: user.uuid) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
        .task {
             if viewModel.users.isEmpty { await viewModel.fetch(serverId: serverId) }
        }
        .refreshable {
            await viewModel.fetch(serverId: serverId)
        }
    }
}
