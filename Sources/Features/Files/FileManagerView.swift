import SwiftUI

class FileManagerViewModel: ObservableObject {
    let serverId: String
    @Published var files: [FileAttributes] = []
    @Published var currentPath: String = "/"
    @Published var isLoading = false
    @Published var error: String?
    
    init(serverId: String) {
        self.serverId = serverId
    }
    
    func listFiles() async {
        await MainActor.run { isLoading = true }
        
        // Mock Implementation for now, as I need to add listFiles to Client
        // In real web app, this would be: GET /api/client/servers/{id}/files/list?directory=...
        
        do {
            let fetchedFiles = try await PterodactylClient.shared.listFiles(serverId: serverId, directory: currentPath)
            
            await MainActor.run {
                self.files = fetchedFiles.sorted { !$0.isFile && $1.isFile } // Directories first
                self.isLoading = false
            }
        } catch {
            print("Error listing files: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
    
    func navigate(to folderName: String) {
        if currentPath == "/" {
            currentPath += folderName
        } else {
            currentPath += "/" + folderName
        }
        Task { await listFiles() }
    }
    
    func navigateUp() {
        guard currentPath != "/" else { return }
        let components = currentPath.split(separator: "/").map(String.init)
        if components.count <= 1 {
            currentPath = "/"
        } else {
            currentPath = "/" + components.dropLast().joined(separator: "/")
        }
        Task { await listFiles() }
    }
    
    func navigateToRoot() async {
        currentPath = "/"
        await listFiles()
    }
    
    func navigate(to path: String) async {
        currentPath = path
        await listFiles()
    }
    
    func loadFiles() async {
        await listFiles()
    }

    func compress(file: FileAttributes) async {
        await MainActor.run { isLoading = true }
        do {
            _ = try await PterodactylClient.shared.compressFiles(serverId: serverId, root: currentPath, files: [file.name])
            await listFiles()
        } catch {
            print("Error compressing: \(error)")
            await MainActor.run { isLoading = false }
        }
    }

    func decompress(file: FileAttributes) async {
        await MainActor.run { isLoading = true }
        do {
            try await PterodactylClient.shared.decompressFile(serverId: serverId, root: currentPath, file: file.name)
            await listFiles()
        } catch {
            print("Error decompressing: \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
}

struct FileManagerView: View {
    @StateObject var viewModel: FileManagerViewModel
    let serverName: String
    let statusState: String
    var stats: WebsocketResponse.Stats?
    var limits: ServerLimits?
    
    // Params removed: selectedTab, onBack, onPowerAction
    
    @State private var pathComponents: [String] = []
    
    init(server: ServerAttributes, serverName: String, statusState: String, stats: WebsocketResponse.Stats? = nil, limits: ServerLimits? = nil) {
        _viewModel = StateObject(wrappedValue: FileManagerViewModel(serverId: server.identifier))
        self.serverName = serverName
        self.statusState = statusState
        self.stats = stats
        self.limits = limits
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Hoisted
                
                // Breadcrumbs and File List
                VStack(alignment: .leading, spacing: 12) {
                    // ... breadcrumbs logic ...
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            Button {
                                Task { await viewModel.navigateToRoot() }
                            } label: {
                                Image(systemName: "house.fill")
                                    .foregroundStyle(.blue)
                            }
                            
                            ForEach(0..<viewModel.currentPath.components(separatedBy: "/").filter({!$0.isEmpty}).count, id: \.self) { index in
                                let components = viewModel.currentPath.components(separatedBy: "/").filter({!$0.isEmpty})
                                Text("/")
                                    .foregroundStyle(.secondary)
                                Button {
                                    // simple reconstruction
                                    let newPath = "/" + components.prefix(index + 1).joined(separator: "/")
                                    Task { await viewModel.navigate(to: newPath) }
                                } label: {
                                    Text(components[index])
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 30)
                    
                    if viewModel.isLoading {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else if let error = viewModel.error {
                        Text(error)
                            .foregroundStyle(.red)
                            .padding()
                    } else {
                        LazyVStack(spacing: 2) {
                            if viewModel.currentPath != "/" && !viewModel.currentPath.isEmpty {
                                Button {
                                     Task { await viewModel.navigateUp() }
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.turn.up.left")
                                            .frame(width: 30)
                                            .foregroundStyle(.blue)
                                        Text("..")
                                            .foregroundStyle(.white)
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                }
                            }
                            
                            ForEach(viewModel.files) { file in
                                FileRow(file: file) {
                                    if file.isDirectory {
                                        Task { await viewModel.navigate(to: file.path) }
                                    } else {
                                        // Edit file
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .refreshable {
            await viewModel.loadFiles()
        }
        .task {
             if viewModel.files.isEmpty { await viewModel.loadFiles() }
        }
    }
}

// Ensure FileAttributes conforms to Identifiable for sheet item
extension FileAttributes: Identifiable {
    public var id: String { name }
}

struct FileRow: View {
    let file: FileAttributes
    let onCompress: () -> Void
    let onDecompress: () -> Void
    
    init(file: FileAttributes, onCompress: @escaping () -> Void = {}, onDecompress: @escaping () -> Void = {}) {
        self.file = file
        self.onCompress = onCompress
        self.onDecompress = onDecompress
    }
    
    var body: some View {
        HStack {
            Image(systemName: file.isFile ? "doc.text" : "folder.fill")
                .foregroundStyle(file.isFile ? .white : .blue)
                .font(.title3)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(file.name)
                    .foregroundStyle(.white)
                    .font(.body)
                
                HStack {
                    Text(formatBytes(file.size))
                    Text("•")
                    Text(file.modifiedAt)
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            if !file.isFile {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding()
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            if file.isFile {
                 if file.name.hasSuffix(".tar.gz") || file.name.hasSuffix(".zip") || file.name.hasSuffix(".rar") {
                     Button(action: onDecompress) {
                         Label("Unarchive", systemImage: "arrow.up.bin")
                     }
                 }
            }
            
            Button(action: onCompress) {
                Label("Archive", systemImage: "archivebox")
            }
        }
    }
    
    func formatBytes(_ bytes: Int) -> String {
        let b = Int64(bytes)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: b)
    }
}
