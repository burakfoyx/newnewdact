import SwiftUI

struct NetworkView: View {
    let serverId: String
    @StateObject private var viewModel: NetworkViewModel
    
    init(serverId: String) {
        self.serverId = serverId
        _viewModel = StateObject(wrappedValue: NetworkViewModel(serverId: serverId))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    ForEach(viewModel.allocations, id: \.id) { allocation in
                        AllocationRow(allocation: allocation)
                    }
                }
            }
            .padding()
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
                HStack {
                    Text(allocation.ip)
                        .font(.monospacedDigit(.headline)())
                        .foregroundStyle(.white)
                    
                    Text(":\(allocation.port)")
                        .font(.monospacedDigit(.headline)())
                        .foregroundStyle(.blue)
                }
                
                if let notes = allocation.notes, !notes.isEmpty {
                     Text(notes)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            if allocation.isDefault {
                Text("PRIMARY")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.green.opacity(0.5), lineWidth: 1)
                    )
            }
        }
        .padding()
        .liquidGlass(variant: .clear, cornerRadius: 16)
    }
}

class NetworkViewModel: ObservableObject {
    let serverId: String
    @Published var allocations: [AllocationAttributes] = []
    @Published var isLoading = false
    
    init(serverId: String) {
        self.serverId = serverId
    }
    
    func loadAllocations() async {
        await MainActor.run { isLoading = true }
        // Implement client fetch
        do {
            let fetched = try await PterodactylClient.shared.fetchAllocations(serverId: serverId)
             await MainActor.run {
                self.allocations = fetched
                self.isLoading = false
            }
        } catch {
             await MainActor.run { isLoading = false }
        }
    }
}
