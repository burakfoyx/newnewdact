import SwiftUI

// MARK: - Network Section

struct NetworkSection: View {
    let server: ServerAttributes
    @State private var allocations: [AllocationAttributes] = []
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                ProgressView().tint(.white)
            } else if allocations.isEmpty {
                ContentUnavailableView("No Allocations", systemImage: "network")
            } else {
                ForEach(allocations, id: \.id) { allocation in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(allocation.ip):\(allocation.port)")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.white)
                                .textSelection(.enabled)
                            
                            if let alias = allocation.ipAlias {
                                Text(alias)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        
                        Spacer()
                        
                        if allocation.isDefault {
                            Text("PRIMARY")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(.blue.opacity(0.1)))
                                .overlay(Capsule().strokeBorder(.blue.opacity(0.3), lineWidth: 1))
                        }
                        
                        if let notes = allocation.notes {
                             Text(notes)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding()
                    .liquidGlassEffect()
                }
                
                // Add allocation button (shown if server has room for more)
                if (server.featureLimits.allocations ?? 0) > allocations.count {
                    Button {
                        // TODO: Wire up allocation assignment API
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                            Text("Add Allocation")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.8))
                            Spacer()
                        }
                        .padding()
                        .liquidGlassEffect()
                    }
                }
            }
        }
        .task {
            do {
                allocations = try await PterodactylClient.shared.fetchAllocations(serverId: server.identifier)
                isLoading = false
            } catch {
                print("Failed to fetch allocations: \(error)")
                isLoading = false
            }
        }
    }
}

// MARK: - Backup Section

struct BackupSection: View {
    let server: ServerAttributes
    @State private var backups: [BackupAttributes] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var newBackupName = ""
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Backups")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .glassEffect(.clear, in: Circle())
                }
            }
            
            if isLoading {
                ProgressView().tint(.white)
            } else if backups.isEmpty {
                 ContentUnavailableView("No Backups", systemImage: "archivebox")
            } else {
                ForEach(backups, id: \.uuid) { backup in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(backup.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(formatBytes(backup.bytes))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                        if backup.completedAt != nil {
                            // Simple text for now, real app would parse date
                            Text("Completed")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                             ProgressView()
                                .scaleEffect(0.5)
                        }
                    }
                    .padding()
                    .liquidGlassEffect()
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteBackup(backup)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .task { await loadBackups() }
        .alert("Create Backup", isPresented: $showCreateSheet) {
            TextField("Backup Name", text: $newBackupName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                Task {
                    _ = try? await PterodactylClient.shared.createBackup(serverId: server.identifier, name: newBackupName.isEmpty ? nil : newBackupName)
                    newBackupName = ""
                    await loadBackups()
                }
            }
        }
    }
    
    func loadBackups() async {
        do {
            backups = try await PterodactylClient.shared.fetchBackups(serverId: server.identifier)
            isLoading = false
        } catch {
            print("Failed to load backups: \(error)")
            isLoading = false
        }
    }
    
    func deleteBackup(_ backup: BackupAttributes) {
        Task {
            try? await PterodactylClient.shared.deleteBackup(serverId: server.identifier, uuid: backup.uuid)
            await loadBackups()
        }
    }
    
    func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Databases

struct DatabaseSection: View {
    let server: ServerAttributes
    @State private var databases: [DatabaseAttributes] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(databases, id: \.id) { db in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "cylinder.split.1x2")
                            .foregroundStyle(.purple)
                        Text(db.name)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    InfoRow(label: "Endpoint", value: "\(db.host.address):\(db.host.port)")
                    InfoRow(label: "Username", value: db.username)
                    // Pterodactyl doesn't show password by default in list, requires reset usually
                }
                .padding()
                .liquidGlassEffect()
            }
        }
        .task {
            databases = (try? await PterodactylClient.shared.fetchDatabases(serverId: server.identifier)) ?? []
        }
    }
}

// MARK: - Schedules (Basic)

struct ScheduleSection: View {
    let server: ServerAttributes
    @State private var schedules: [ScheduleAttributes] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(schedules, id: \.id) { schedule in
                HStack {
                    VStack(alignment: .leading) {
                        Text(schedule.name)
                            .foregroundStyle(.white)
                        Text("Next: \(schedule.nextRunAt ?? "Never")")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    if schedule.isActive {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.green)
                    } else {
                         Image(systemName: "clock")
                            .foregroundStyle(.gray)
                    }
                }
                .padding()
                .liquidGlassEffect()
            }
        }
        .task {
            schedules = (try? await PterodactylClient.shared.fetchSchedules(serverId: server.identifier)) ?? []
        }
    }
}

// MARK: - Users (Basic)

struct UserSection: View {
    let server: ServerAttributes
    @State private var users: [SubuserAttributes] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(users, id: \.uuid) { user in
                HStack {
                    AsyncImage(url: URL(string: user.image ?? "")) { img in
                        img.resizable().clipShape(Circle())
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading) {
                        Text(user.username)
                            .foregroundStyle(.white)
                        Text(user.email)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding()
                .liquidGlassEffect()
            }
        }
        .task {
            users = (try? await PterodactylClient.shared.fetchUsers(serverId: server.identifier)) ?? []
        }
    }
}

// MARK: - Settings

