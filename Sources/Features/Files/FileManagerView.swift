import SwiftUI

class FileManagerViewModel: ObservableObject {
    let serverId: String
    @Published var files: [FileAttributes] = []
    @Published var currentPath: String = "/"
    @Published var isLoading = false
    
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
            await MainActor.run { isLoading = false }
        }
    }
}

struct FileManagerView: View {
    @StateObject private var viewModel: FileManagerViewModel
    @State private var selectedFileForEditing: FileAttributes?
    
    init(server: ServerAttributes) {
        _viewModel = StateObject(wrappedValue: FileManagerViewModel(serverId: server.identifier))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 240) // Spacer for header
            // Path Breadcrumb
            HStack {
                Button(action: { viewModel.navigateUp() }) {
                    Image(systemName: "arrow.turn.up.left")
                        .foregroundStyle(.white)
                }
                .disabled(viewModel.currentPath == "/")
                .opacity(viewModel.currentPath == "/" ? 0.3 : 1.0)
                
                Text(viewModel.currentPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { Task { await viewModel.listFiles() } }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.files, id: \.name) { file in
                            FileRow(
                                file: file,
                                onCompress: { Task { await viewModel.compress(file: file) } },
                                onDecompress: { Task { await viewModel.decompress(file: file) } }
                            )
                            .onTapGesture {
                                if !file.isFile {
                                    viewModel.navigate(to: file.name)
                                } else {
                                    selectedFileForEditing = file
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $selectedFileForEditing) { file in
            let fullPath = viewModel.currentPath == "/" ? file.name : "\(viewModel.currentPath)/\(file.name)"
            FileEditorView(serverId: viewModel.serverId, filePath: fullPath)
        }
        .task {
            await viewModel.listFiles()
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
        .liquidGlass(variant: .clear, cornerRadius: 12)
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
