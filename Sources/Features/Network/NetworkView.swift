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
    @Environment(\.clipboard) var clipboard
    
    init(serverId: String) {
        _viewModel = StateObject(wrappedValue: NetworkViewModel(serverId: serverId))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading && viewModel.allocations.isEmpty {
                    ProgressView().tint(.white)
                        .padding(.top, 40)
                } else if let error = viewModel.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.8))
                        Button("Retry") {
                            Task { await viewModel.loadAllocations() }
                        }
                        .buttonStyle(LiquidButtonStyle())
                    }
                    .padding(.top, 40)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
                } else if viewModel.allocations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No allocations found.")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(viewModel.allocations, id: \.id) { allocation in
                        AllocationRow(allocation: allocation)
                    }
                }
            }
            .padding()
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
                        .foregroundStyle(.white)
                    
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
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
            }
            
            Spacer()
            
            if let notes = allocation.notes, !notes.isEmpty {
                Image(systemName: "note.text")
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding()
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button {
                UIPasteboard.general.string = "\(allocation.ipAlias ?? allocation.ip):\(allocation.port)"
            } label: {
                Label("Copy Address", systemImage: "doc.on.doc")
            }
        }
    }
}
