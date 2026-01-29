import SwiftUI

class BackupViewModel: ObservableObject {
    let serverId: String
    @Published var backups: [BackupAttributes] = []
    @Published var isLoading = false
    
    init(serverId: String) {
        self.serverId = serverId
    }
    
    func loadBackups() async {
        await MainActor.run { isLoading = true }
        do {
            let fetched = try await PterodactylClient.shared.fetchBackups(serverId: serverId)
            await MainActor.run {
                self.backups = fetched
                self.isLoading = false
            }
        } catch {
             await MainActor.run { isLoading = false }
        }
    }
    
    func createBackup() async {
        // Implement create
    }
}

struct BackupView: View {
    @StateObject private var viewModel: BackupViewModel
    
    init(serverId: String) {
        _viewModel = StateObject(wrappedValue: BackupViewModel(serverId: serverId))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else if viewModel.backups.isEmpty {
                     Text("No backups found.")
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.top, 40)
                } else {
                    ForEach(viewModel.backups, id: \.uuid) { backup in
                        BackupRow(backup: backup)
                    }
                }
            }
            .padding()
        }
        .task {
            await viewModel.loadBackups()
        }
    }
}

struct BackupRow: View {
    let backup: BackupAttributes
    
    var body: some View {
        HStack {
            Image(systemName: "archivebox.fill")
                .font(.title2)
                .foregroundStyle(.orange)
                .padding(8)
                .background(.orange.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading) {
                Text(backup.name)
                    .foregroundStyle(.white)
                    .font(.headline)
                Text(backup.uuid.prefix(8))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            if backup.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding()
        .liquidGlass(variant: .clear)
    }
}
