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
}

struct UsersView: View {
    let serverId: String
    @StateObject private var viewModel = UsersViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView().tint(.white).padding(.top, 40)
                } else if let error = viewModel.error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title)
                            .foregroundStyle(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding()
                } else if viewModel.users.isEmpty {
                     // Empty State
                     VStack(spacing: 12) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("No subusers found")
                            .foregroundStyle(.white.opacity(0.6))
                     }
                     .frame(maxWidth: .infinity)
                     .padding(.top, 60)
                } else {
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
                    }
                }
            }
            .padding()
            .padding(.bottom, 80)
        }
        .task {
             if viewModel.users.isEmpty { await viewModel.fetch(serverId: serverId) }
        }
        .refreshable {
            await viewModel.fetch(serverId: serverId)
        }
    }
}
