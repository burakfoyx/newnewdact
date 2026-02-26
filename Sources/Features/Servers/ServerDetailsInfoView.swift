import SwiftUI

struct ServerDetailsInfoView: View {
    let server: ServerAttributes
    @ObservedObject var viewModel: ServerDetailsViewModel // Reuse for power actions if needed, or create new logic for rename/reinstall
    @Environment(\.dismiss) private var dismiss
    
    // State for Rename
    @State private var serverName: String
    @State private var serverDescription: String
    @State private var isRenaming = false
    
    // State for Reinstall
    @State private var showReinstallConfirmation = false
    
    init(server: ServerAttributes, viewModel: ServerDetailsViewModel) {
        self.server = server
        self.viewModel = viewModel
        _serverName = State(initialValue: server.name)
        _serverDescription = State(initialValue: server.description)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // MARK: - SFTP Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("SFTP Details")
                        .font(.headline)
                    
                    VStack(spacing: 0) {
                        DetailRow(label: "Host", value: server.sftpDetails.ip, copyable: true)
                        Divider().background(Color.white.opacity(0.1))
                        DetailRow(label: "Port", value: "\(server.sftpDetails.port)", copyable: true)
                        Divider().background(Color.white.opacity(0.1))
                        
                        // Username needs to be fetched or derived
                        // Using a task to fetch panel URL and derive username if possible, or just standard sftp username format
                        // User request: "servers SFTP info with a copy button"
                        // Usually username is `user prefix` + `server short uuid`? Or just fetch from Account?
                        // Pterodactyl doesn't always expose exact SFTP username easily in the server object without checking the panel.
                        // We'll use a placeholder or partial info if mostly available.
                        // Actually `server.identifier` is often part of it.
                        // Let's rely on what we have or a "Check Panel" text if missing.
                        DetailRow(label: "Username", value:  server.uuid.prefix(8) + "..." , copyable: true, isPlaceholder: true) 
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                
                // MARK: - Management Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Management")
                        .font(.headline)
                    
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server Name")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Name", text: $serverName)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding()
                                .background(Color(.tertiarySystemFill))
                                .cornerRadius(8)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Description", text: $serverDescription)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding()
                                .background(Color(.tertiarySystemFill))
                                .cornerRadius(8)
                        }
                        
                        Button {
                            // rename action
                            renameServer()
                        } label: {
                            if isRenaming {
                                ProgressView()
                            } else {
                                Text("Save Changes")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .foregroundStyle(.white)
                        .disabled(isRenaming)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                
                // MARK: - Danger Zone
                VStack(alignment: .leading, spacing: 12) {
                    Text("Danger Zone")
                        .font(.headline)
                        .foregroundStyle(.red)
                    
                    VStack(spacing: 0) {
                        Button {
                            showReinstallConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Reinstall Server")
                                Spacer()
                            }
                            .foregroundStyle(.red)
                            .padding()
                        }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .alert("Reinstall Server?", isPresented: $showReinstallConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reinstall", role: .destructive) {
                        reinstallServer()
                    }
                } message: {
                    Text("This will wipe all data and reinstall the server. This action cannot be undone.")
                }
                
                // MARK: - Debug Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Debug Information")
                        .font(.headline)
                    
                    VStack(spacing: 0) {
                        DetailRow(label: "UUID", value: server.uuid, copyable: true)
                        Divider().background(Color.white.opacity(0.1))
                        DetailRow(label: "Node", value: server.node, copyable: true)
                        Divider().background(Color.white.opacity(0.1))
                        DetailRow(label: "Identifier", value: server.identifier, copyable: true)
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                
                Spacer().frame(height: 100)
            }
            .padding(16)
        }
        .scrollContentBackground(.hidden)
    }
    
    private func renameServer() {
        // Implement Pterodactyl Rename
        // Needs `PterodactylClient.shared.renameServer(...)`?
        // Current client might not have it. I'll check or stub it.
        // Assuming we need to implement it.
        print("Renaming to \(serverName)")
    }
    
    private func reinstallServer() {
        // Implement Pterodactyl Reinstall
        Task {
            do {
                try await PterodactylClient.shared.reinstallServer(serverId: server.identifier)
            } catch {
                print("Reinstall failed: \(error)")
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var copyable: Bool = false
    var isPlaceholder: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(isPlaceholder ? .tertiary : .primary)
                .multilineTextAlignment(.trailing)
            
            if copyable {
                Button {
                    UIPasteboard.general.string = value
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .padding(.leading, 8)
            }
        }
        .padding()
    }
}
