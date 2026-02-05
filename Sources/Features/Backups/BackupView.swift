import SwiftUI

class BackupViewModel: ObservableObject {
    let serverId: String
    @Published var backups: [BackupAttributes] = []
    @Published var isLoading = false
    @Published var error: String?
    
    init(serverId: String) {
        self.serverId = serverId
    }
    
    func loadBackups() async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let fetched = try await PterodactylClient.shared.fetchBackups(serverId: serverId)
            await MainActor.run {
                self.backups = fetched
                self.isLoading = false
            }
        } catch {
             await MainActor.run { 
                 isLoading = false
                 self.error = "Failed to load backups: \(error.localizedDescription)"
             }
        }
    }
    
    func createBackup(name: String) async {
        await MainActor.run { isLoading = true }
        do {
            _ = try await PterodactylClient.shared.createBackup(serverId: serverId, name: name.isEmpty ? nil : name)
            await MainActor.run {
                // Prepend to list optimistically or reload?
                // Reload is safer for status
                self.isLoading = false
            }
            await loadBackups()
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.error = "Failed to create backup: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteBackup(uuid: String) async {
        do {
            try await PterodactylClient.shared.deleteBackup(serverId: serverId, uuid: uuid)
            await MainActor.run {
                if let index = backups.firstIndex(where: { $0.uuid == uuid }) {
                    backups.remove(at: index)
                }
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to delete: \(error.localizedDescription)"
            }
        }
    }
    
    func getDownloadUrl(uuid: String) async -> URL? {
        do {
            return try await PterodactylClient.shared.getBackupDownloadUrl(serverId: serverId, uuid: uuid)
        } catch {
            await MainActor.run {
                self.error = "Failed to get download link: \(error.localizedDescription)"
            }
            return nil
        }
    }
}

struct BackupView: View {
    @StateObject private var viewModel: BackupViewModel
    @State private var showingCreateSheet = false
    @State private var newBackupName = ""
    @Environment(\.openURL) var openURL
    
    init(serverId: String) {
        _viewModel = StateObject(wrappedValue: BackupViewModel(serverId: serverId))
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let error = viewModel.error {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    if viewModel.isLoading && viewModel.backups.isEmpty {
                        ProgressView().tint(.white)
                            .padding(.top, 40)
                    } else if viewModel.backups.isEmpty && !viewModel.isLoading {
                         VStack(spacing: 12) {
                             Image(systemName: "archivebox")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.3))
                             Text("No backups found.")
                                .foregroundStyle(.white.opacity(0.5))
                         }
                         .padding(.top, 40)
                    } else {
                        ForEach(viewModel.backups, id: \.uuid) { backup in
                            BackupRow(backup: backup)
                                .contextMenu {
                                    Button {
                                        Task {
                                            if let url = await viewModel.getDownloadUrl(uuid: backup.uuid) {
                                                openURL(url)
                                            }
                                        }
                                    } label: {
                                        Label("Download", systemImage: "arrow.down.circle")
                                    }
                                    
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteBackup(uuid: backup.uuid) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.deleteBackup(uuid: backup.uuid) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        Task {
                                            if let url = await viewModel.getDownloadUrl(uuid: backup.uuid) {
                                                openURL(url)
                                            }
                                        }
                                    } label: {
                                        Label("Download", systemImage: "arrow.down")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 80) // Space for FAB
            }
            .refreshable {
                await viewModel.loadBackups()
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .glassEffect(.clear.interactive(), in: Circle())
                    }
                    .padding()
                }
            }
        }
        // Toolbar removed
        .task {
            await viewModel.loadBackups()
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                Form {
                    Section(header: Text("Backup Name (Optional)")) {
                        TextField("My Backup", text: $newBackupName)
                    }
                    
                    Section(footer: Text("Backups might take a few minutes depending on server size.")) {
                        Button("Create Backup") {
                            Task {
                                await viewModel.createBackup(name: newBackupName)
                                newBackupName = ""
                                showingCreateSheet = false
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
                .navigationTitle("New Backup")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingCreateSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(backup.name)
                    .foregroundStyle(.white)
                    .font(.headline)
                
                HStack {
                    Text(backup.uuid.prefix(8))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text(formatBytes(Int64(backup.bytes)))
                        .font(.caption)
                    
                     Text("•")
                    
                    Text(formatDate(backup.createdAt))
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.6))
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
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func formatDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
             let formatter = DateFormatter()
             formatter.dateStyle = .medium
             formatter.timeStyle = .short
             return formatter.string(from: date)
        }
        return dateString
    }
}
