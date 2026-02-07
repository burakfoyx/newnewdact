import SwiftUI

@MainActor
class ServerSettingsViewModel: ObservableObject {
    let server: ServerAttributes
    @Published var isLoading = false
    @Published var error: String?
    
    init(server: ServerAttributes) {
        self.server = server
    }
    
    func reinstallServer() async {
        isLoading = true
        do {
            try await PterodactylClient.shared.reinstallServer(serverId: server.identifier)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct ServerSettingsView: View {
    @StateObject private var viewModel: ServerSettingsViewModel
    
    let serverName: String
    let statusState: String
    var stats: WebsocketResponse.Stats?
    var limits: ServerLimits?
    
    // Params removed: selectedTab, onBack, onPowerAction
    
    @State private var showingReinstallConfirm = false
    
    init(server: ServerAttributes, serverName: String, statusState: String, stats: WebsocketResponse.Stats? = nil, limits: ServerLimits? = nil) {
        _viewModel = StateObject(wrappedValue: ServerSettingsViewModel(server: server))
        self.serverName = serverName
        self.statusState = statusState
        self.stats = stats
        self.limits = limits
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                 // Header Hoisted
                
                // Settings Options
                VStack(spacing: 12) {
                    Button(role: .destructive) {
                        showingReinstallConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Reinstall Server")
                            Spacer()
                        }
                        .padding()
                        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .confirmationDialog("Reinstall Server?", isPresented: $showingReinstallConfirm) {
                         Button("Reinstall", role: .destructive) {
                             Task { await viewModel.reinstallServer() }
                         }
                         Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will reinstall the server. Your files should be safe, but downtime will occur.")
                    }
                    
                    if let error = viewModel.error {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .padding()
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
                
                // Info Card
                VStack(spacing: 12) {
                    Label("Server Information", systemImage: "info.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider().overlay(.white.opacity(0.3))
                    
                    InfoRow(label: "Server Name", value: viewModel.server.name)
                    InfoRow(label: "UUID", value: viewModel.server.uuid)
                    InfoRow(label: "Identifier", value: viewModel.server.identifier)
                    InfoRow(label: "Node", value: viewModel.server.node)
                    InfoRow(label: "Description", value: viewModel.server.description)
                }
                .padding()
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
                
                // SFTP Card
                VStack(spacing: 12) {
                    Label("SFTP Details", systemImage: "network")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider().overlay(.white.opacity(0.3))
                    
                    InfoRow(label: "Host", value: "\(viewModel.server.sftpDetails.ip):\(viewModel.server.sftpDetails.port)")
                    // Simple prediction of username, can be inaccurate but helpful
                    InfoRow(label: "Username", value: "<username>.\(viewModel.server.identifier)")
                    
                    Button(action: {
                        UIPasteboard.general.string = "sftp://\(viewModel.server.sftpDetails.ip):\(viewModel.server.sftpDetails.port)"
                    }) {
                        Label("Copy SFTP URL", systemImage: "doc.on.doc")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .padding(8)
                            .glassEffect(.clear, in: Capsule())
                    }
                }
                .padding()
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
                
                // Limits Card
                VStack(spacing: 12) {
                    Label("Resource Limits", systemImage: "gauge")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider().overlay(.white.opacity(0.3))
                    
                    InfoRow(label: "Memory", value: "\(viewModel.server.limits.memory ?? 0) MB")
                    InfoRow(label: "Disk", value: "\(viewModel.server.limits.disk ?? 0) MB")
                    InfoRow(label: "CPU", value: "\(viewModel.server.limits.cpu ?? 0)%")
                    InfoRow(label: "Swap", value: "\(viewModel.server.limits.swap ?? 0) MB")
                }
                .padding()
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
            .padding(.bottom, 20)
        }
    }
}

// Reusing InfoRow from SettingsView.swift if public, or redefining. 
// SettingsView.swift defines it. I should check access level. It is internal.
// I will redefine it here or use the one in SettingsView if accessible.
// Since they are in the same module, it should be visible.
