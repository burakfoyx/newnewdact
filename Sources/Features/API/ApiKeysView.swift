import SwiftUI

@MainActor
class ApiKeysViewModel: ObservableObject {
    @Published var apiKeys: [ApiKeyAttributes] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCreateSheet = false
    
    // Create form
    @Published var newDescription = ""
    @Published var newAllowedIps = ""
    
    func fetchKeys() async {
        isLoading = true
        do {
            apiKeys = try await PterodactylClient.shared.fetchApiKeys()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func createKey() async {
        isLoading = true
        do {
            let ips = newAllowedIps.split(separator: "\n").map { String($0) }
            let newKey = try await PterodactylClient.shared.createApiKey(description: newDescription, allowedIps: ips)
            apiKeys.append(newKey)
            showCreateSheet = false
            newDescription = ""
            newAllowedIps = ""
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func deleteKey(identifier: String) async {
        do {
            try await PterodactylClient.shared.deleteApiKey(identifier: identifier)
            apiKeys.removeAll { $0.identifier == identifier }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ApiKeysView: View {
    @StateObject private var viewModel = ApiKeysViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.apiKeys.isEmpty {
                    ProgressView()
                        .tint(.white)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.apiKeys, id: \.identifier) { key in
                                ApiKeyRow(key: key) {
                                    Task { await viewModel.deleteKey(identifier: key.identifier) }
                                }
                            }
                        }
                        .padding()
                    }
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await viewModel.fetchKeys()
                    }
                }
                
                VStack {
                     Spacer()
                     HStack {
                         Spacer()
                         Button(action: { viewModel.showCreateSheet = true }) {
                             Image(systemName: "plus")
                                 .font(.title2.bold())
                                 .foregroundStyle(.white)
                                 .frame(width: 56, height: 56)
                                 .glassEffect(.regular.interactive(), in: Circle())
                         }
                         .padding()
                     }
                }
            }
            .navigationTitle("API Keys")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $viewModel.showCreateSheet) {
            NavigationStack {
                Form {
                    Section("Details") {
                        TextField("Description", text: $viewModel.newDescription)
                        TextEditor(text: $viewModel.newAllowedIps)
                            .frame(height: 100)
                            .overlay(alignment: .topLeading) {
                                if viewModel.newAllowedIps.isEmpty {
                                    Text("Allowed IPs (one per line)\nLeave empty for all")
                                        .foregroundStyle(.secondary)
                                        .padding(8)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                }
                .navigationTitle("New API Key")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { viewModel.showCreateSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Create") {
                            Task { await viewModel.createKey() }
                        }
                        .disabled(viewModel.newDescription.isEmpty)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .task {
            await viewModel.fetchKeys()
        }
    }
}

struct ApiKeyRow: View {
    let key: ApiKeyAttributes
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(key.description)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(key.identifier)
                     .font(.caption.monospaced())
                     .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "calendar")
                    Text("Created: \(key.createdAt.prefix(10))")
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(.red.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding()
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
    }
}
