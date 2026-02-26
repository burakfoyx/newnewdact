import SwiftUI

class NetworkViewModel: ObservableObject {
    let serverId: String
    @Published var allocations: [AllocationAttributes] = []
    @Published var isLoading = false
    @Published var error: String?
    
    init(serverId: String) {
        self.serverId = serverId
    }
    
    func loadAllocations() async {
        await MainActor.run { 
            isLoading = true 
            error = nil
        }
        do {
            let fetched = try await PterodactylClient.shared.fetchAllocations(serverId: serverId)
            await MainActor.run {
                self.allocations = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run { 
                self.error = "Failed to load allocations: \(error.localizedDescription)"
                self.isLoading = false 
            }
        }
    }
}

struct NetworkView: View {
    @StateObject private var viewModel: NetworkViewModel
    
    let serverName: String
    let statusState: String
    var stats: WebsocketResponse.Stats?
    var limits: ServerLimits?
    
    // Params removed: selectedTab, onBack, onPowerAction
    
    init(server: ServerAttributes, serverName: String, statusState: String, stats: WebsocketResponse.Stats? = nil, limits: ServerLimits? = nil) {
        _viewModel = StateObject(wrappedValue: NetworkViewModel(serverId: server.identifier))
        self.serverName = serverName
        self.statusState = statusState
        self.stats = stats
        self.limits = limits
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                 // Header Hoisted
                
                if viewModel.isLoading && viewModel.allocations.isEmpty {
                    ProgressView()
                        .padding(.top, 40)
                } else if let error = viewModel.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await viewModel.loadAllocations() }
                        }
                        .buttonStyle(LiquidButtonStyle())
                    }
                    .padding(.top, 40)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                } else if viewModel.allocations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)
                        Text("No allocations found.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(viewModel.allocations, id: \.id) { allocation in
                        AllocationRow(allocation: allocation)
                    }
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
        .refreshable {
            await viewModel.loadAllocations()
        }
        .task {
            await viewModel.loadAllocations()
        }
    }
}

struct AllocationRow: View {
    let allocation: AllocationAttributes
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(allocation.ipAlias ?? allocation.ip)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if allocation.isDefault {
                        Text("PRIMARY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                
                Text("Port: \(allocation.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            
            Spacer()
            
            if let notes = allocation.notes, !notes.isEmpty {
                Image(systemName: "note.text")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button {
                UIPasteboard.general.string = "\(allocation.ipAlias ?? allocation.ip):\(allocation.port)"
            } label: {
                Label("Copy Address", systemImage: "doc.on.doc")
            }
        }
    }
}
