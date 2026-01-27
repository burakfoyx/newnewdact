import SwiftUI

class ServerListViewModel: ObservableObject {
    @Published var servers: [ServerAttributes] = []
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
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
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
                                ServerRow(server: server)
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
            await viewModel.loadServers()
        }
    }
}

struct ServerRow: View {
    let server: ServerAttributes
    
    var statusColor: Color {
        if server.isSuspended { return .orange }
        if server.isInstalling { return .blue }
        return .green // Assume online/ready if not suspended/installing
    }

    var body: some View {
        HStack {
            // Status Indicator (Dot) - Kept for specific detail
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
