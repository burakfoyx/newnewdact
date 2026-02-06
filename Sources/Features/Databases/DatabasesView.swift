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
}

struct DatabasesView: View {
    let serverId: String
    @StateObject private var viewModel = DatabasesViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Color.clear.frame(height: 140) // Header spacer
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                        .padding(.top, 40)
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
                } else if viewModel.databases.isEmpty {
                     // Empty State
                     VStack(spacing: 12) {
                        Image(systemName: "cylinder.split.1x2.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("No databases found")
                            .foregroundStyle(.white.opacity(0.6))
                     }
                     .frame(maxWidth: .infinity)
                     .padding(.top, 60)
                } else {
                    ForEach(viewModel.databases, id: \.id) { db in
                        LiquidGlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "cylinder.fill")
                                        .foregroundStyle(.blue)
                                    Text(db.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                
                                Divider().background(Color.white.opacity(0.1))
                                
                                HStack {
                                    Label(db.host.address + ":" + String(db.host.port), systemImage: "network")
                                    Spacer()
                                    Label(db.username, systemImage: "person.circle")
                                }
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 80) // Space for tab bar
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
