import SwiftUI

struct FileManagerView: View {
    let server: ServerAttributes
    @StateObject private var viewModel = FileListViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Breadcrumbs / Path
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    Button(action: { viewModel.navigateTo(path: "/") }) {
                        Image(systemName: "house.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .padding(8)
                            .background(Color.accentColor, in: Circle())
                    }
                    
                    ForEach(viewModel.pathComponents, id: \.self) { component in
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        
                        Button(action: { viewModel.navigateTo(component: component) }) {
                            Text(component)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.tertiarySystemFill), in: Capsule())
                        }
                    }
                }
                .padding()
            }

            
            // File List
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .tint(.accentColor)
                Spacer()
            } else if let error = viewModel.errorMessage {
                Spacer()
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Reload") {
                        Task { await viewModel.loadFiles() }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            } else {
                List {
                    if viewModel.files.isEmpty {
                        ContentUnavailableView("Folder is empty", systemImage: "folder")
                            .listRowBackground(Color.clear)
                    }
                    
                    ForEach(viewModel.files) { file in
                        FileRow(file: file)
                            .onTapGesture {
                                if !file.isFile {
                                    viewModel.enterDirectory(name: file.name)
                                } else {
                                    viewModel.openFile(file)
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteFile(file)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    viewModel.startRename(file)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .refreshable {
                    await viewModel.loadFiles()
                }
            }
        }
        .onAppear {
            viewModel.server = server
            Task { await viewModel.loadFiles() }
        }
        .sheet(item: $viewModel.editingFile) { file in
            FileEditorView(serverId: server.identifier, filePath: viewModel.currentPath + (viewModel.currentPath.hasSuffix("/") ? "" : "/") + file.name)
        }
        .alert("Rename \(viewModel.fileToRename?.name ?? "")", isPresented: $viewModel.showRenameAlert) {
            TextField("New Name", text: $viewModel.renameInput)
            Button("Cancel", role: .cancel) { }
            Button("Rename") {
                Task { await viewModel.performRename() }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { viewModel.showCreateFolderAlert = true }) {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    Button(action: { viewModel.showCreateFileAlert = true }) {
                        Label("New File", systemImage: "doc.badge.plus")
                    }
                    Button(action: { Task { await viewModel.loadFiles() } }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.primary)
                }
            }
        }
        .alert("New Folder", isPresented: $viewModel.showCreateFolderAlert) {
            TextField("Folder Name", text: $viewModel.newFolderInput)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                Task { await viewModel.createFolder() }
            }
        }
    }
}

struct FileRow: View {
    let file: FileAttributes
    
    var icon: String {
        if !file.isFile { return "folder.fill" }
        if file.name.hasSuffix(".json") || file.name.hasSuffix(".yml") { return "gearshape" }
        if file.name.hasSuffix(".log") || file.name.hasSuffix(".txt") { return "doc.text" }
        return "doc"
    }
    
    var iconColor: Color {
        if !file.isFile { return .yellow }
        return .blue
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(file.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                
                HStack {
                    Text(formatBytes(file.size))
                    Text("•")
                    Text(file.modifiedAt) // In real app, parse ISO string to Date
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - ViewModel

class FileListViewModel: ObservableObject {
    @Published var files: [FileAttributes] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentPath: String = "/"
    
    @Published var editingFile: FileAttributes?
    @Published var fileToRename: FileAttributes?
    @Published var showRenameAlert = false
    @Published var renameInput = ""
    
    @Published var showCreateFolderAlert = false
    @Published var showCreateFileAlert = false
    @Published var newFolderInput = ""
    
    var server: ServerAttributes?
    
    var pathComponents: [String] {
        currentPath.split(separator: "/").map(String.init)
    }
    
    func loadFiles() async {
        guard let server = server else { return }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.files = []
        }
        
        do {
            let files = try await PterodactylClient.shared.listFiles(serverId: server.identifier, directory: currentPath)
            
            await MainActor.run {
                // Sort: Folders first, then files. Alphabetical.
                self.files = files.sorted {
                    if $0.isFile != $1.isFile {
                         return !$0.isFile // Folders (not file) first
                    }
                    return $0.name < $1.name
                }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func navigateTo(path: String) {
        currentPath = path
        Task { await loadFiles() }
    }
    
    func navigateTo(component: String) {
        // Reconstruct path up to this component
        // E.g. /home/container/plugins -> click "container" -> /home/container
        if let index = pathComponents.firstIndex(of: component) {
                let newComponents = pathComponents[0...index]
                let path = "/" + newComponents.joined(separator: "/")
                navigateTo(path: path)
        }
    }
    
    func enterDirectory(name: String) {
        let separator = currentPath.hasSuffix("/") ? "" : "/"
        let newPath = "\(currentPath)\(separator)\(name)"
        navigateTo(path: newPath)
    }
    
    func openFile(_ file: FileAttributes) {
        editingFile = file
    }
    
    func deleteFile(_ file: FileAttributes) {
        guard let server = server else { return }
        Task {
            do {
                try await PterodactylClient.shared.deleteFiles(serverId: server.identifier, root: currentPath, files: [file.name])
                await loadFiles()
            } catch {
                print("Failed to delete: \(error)")
            }
        }
    }
    
    func startRename(_ file: FileAttributes) {
        fileToRename = file
        renameInput = file.name
        showRenameAlert = true
    }
    
    func performRename() async {
        guard let server = server, let file = fileToRename else { return }
        do {
            try await PterodactylClient.shared.renameFile(serverId: server.identifier, root: currentPath, files: [(from: file.name, to: renameInput)])
            await loadFiles()
        } catch {
            print("Failed to rename: \(error)")
        }
        fileToRename = nil
    }
    
    func createFolder() async {
        guard let server = server, !newFolderInput.isEmpty else { return }
        do {
            try await PterodactylClient.shared.createDirectory(serverId: server.identifier, root: currentPath, name: newFolderInput)
            await loadFiles()
        } catch {
             print("Failed to create folder: \(error)")
        }
        newFolderInput = ""
    }
}
