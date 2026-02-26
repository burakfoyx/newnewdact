import SwiftUI

class FileEditorViewModel: ObservableObject {
    let serverId: String
    let filePath: String
    
    @Published var content: String = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    
    init(serverId: String, filePath: String) {
        self.serverId = serverId
        self.filePath = filePath
    }
    
    func loadContent() async {
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let text = try await PterodactylClient.shared.getFileContent(serverId: serverId, filePath: filePath)
            await MainActor.run {
                self.content = text
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func saveContent() async {
        await MainActor.run { isSaving = true; errorMessage = nil }
        do {
            try await PterodactylClient.shared.writeFileContent(serverId: serverId, filePath: filePath, content: content)
            await MainActor.run { isSaving = false }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to save: \(error.localizedDescription)"
                self.isSaving = false
            }
        }
    }
}

struct FileEditorView: View {
    @StateObject private var viewModel: FileEditorViewModel
    @Environment(\.dismiss) var dismiss
    
    init(serverId: String, filePath: String) {
        _viewModel = StateObject(wrappedValue: FileEditorViewModel(serverId: serverId, filePath: filePath))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if viewModel.isLoading {
                    ProgressView("Loading File...")
                        .tint(.white)
                        .foregroundStyle(.white)
                } else {
                    VStack(spacing: 0) {
                        // Simple Toolbar
                        HStack {
                            Text(viewModel.filePath)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Spacer()
                            if viewModel.isSaving {
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        
                        TextEditor(text: $viewModel.content)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden) // Required for dark background
                            .background(Color.black)
                            .foregroundStyle(.white) // Classic terminal look
                            .padding(4)
                    }
                }
                
                if let error = viewModel.errorMessage {
                    VStack {
                        Spacer()
                        Text(error)
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                            .padding()
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { 
                            await viewModel.saveContent()
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .bold()
                }
            }
            .navigationTitle("Editor")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadContent()
            }
        }
    }
}
