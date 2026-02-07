import SwiftUI

class StartupViewModel: ObservableObject {
    let serverId: String
    @Published var variables: [StartupVariable] = []
    @Published var isLoading = false
    
    init(serverId: String) {
        self.serverId = serverId
    }
    
    func loadVariables() async {
        await MainActor.run { isLoading = true }
        do {
            let fetched = try await PterodactylClient.shared.fetchStartupVariables(serverId: serverId)
            await MainActor.run {
                self.variables = fetched
                self.isLoading = false
            }
        } catch {
             await MainActor.run { isLoading = false }
        }
    }
    
    func updateVariable(key: String, value: String) async {
        await MainActor.run { isLoading = true }
        do {
            let updated = try await PterodactylClient.shared.updateStartupVariable(serverId: serverId, key: key, value: value)
            await MainActor.run {
                if let index = variables.firstIndex(where: { $0.envVariable == key }) {
                    variables[index] = updated
                }
                isLoading = false
            }
        } catch {
             await MainActor.run { isLoading = false }
             print("Error updating variable: \(error)")
        }
    }
}

struct StartupView: View {
    @StateObject private var viewModel: StartupViewModel
    
    let serverName: String
    let statusState: String
    var stats: WebsocketResponse.Stats?
    var limits: ServerLimits?
    
    init(server: ServerAttributes, serverName: String, statusState: String, stats: WebsocketResponse.Stats? = nil, limits: ServerLimits? = nil) {
        _viewModel = StateObject(wrappedValue: StartupViewModel(serverId: server.identifier))
        self.serverName = serverName
        self.statusState = statusState
        self.stats = stats
        self.limits = limits
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading && viewModel.variables.isEmpty {
                    ProgressView().tint(.white)
                        .padding(.top, 40)
                } else if let error = viewModel.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.variables, id: \.envVariable) { variable in
                            VariableRow(variable: variable, onUpdate: { key, value in
                                Task { await viewModel.updateVariable(key: key, value: value) }
                            })
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 20)
        }
        .task {
            await viewModel.loadVariables()
        }
        .refreshable {
            await viewModel.loadVariables()
        }
    }
}

struct VariableRow: View {
    let variable: StartupVariable
    let onUpdate: (String, String) -> Void
    @State private var text: String
    @State private var isEditing = false
    
    init(variable: StartupVariable, onUpdate: @escaping (String, String) -> Void) {
        self.variable = variable
        self.onUpdate = onUpdate
        _text = State(initialValue: variable.serverValue.isEmpty ? variable.defaultValue : variable.serverValue)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(variable.name)
                .font(.headline)
                .foregroundStyle(.white)
            
            Text(variable.description)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(2)
            
            HStack {
                Text(variable.envVariable)
                    .font(.monospaced(.caption2)())
                    .padding(4)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)
                    .foregroundStyle(.yellow)
                Spacer()
            }

            HStack {
                if variable.isEditable {
                    TextField("Value", text: $text)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(8)
                        .onChange(of: text) {
                            isEditing = true
                        }
                    
                    if isEditing {
                        Button {
                            onUpdate(text)
                            isEditing = false
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                    }
                } else {
                    Text(text)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(8)
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.gray)
                }
            }
        }
        .padding()
        .liquidGlass(variant: .clear)
    }
}
