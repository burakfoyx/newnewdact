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
    
    // Future: Update variable
}

struct StartupView: View {
    @StateObject private var viewModel: StartupViewModel
    
    init(serverId: String) {
        _viewModel = StateObject(wrappedValue: StartupViewModel(serverId: serverId))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    ForEach(viewModel.variables) { variable in
                        StartupVariableRow(variable: variable)
                    }
                }
            }
            .padding()
        }
        .task {
            await viewModel.loadVariables()
        }
    }
}

struct StartupVariableRow: View {
    let variable: StartupVariable
    
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

            // Display value (read only for now)
            Text(variable.serverValue.isEmpty ? variable.defaultValue : variable.serverValue)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)
                .foregroundStyle(.white)
        }
        .padding()
        .liquidGlass(variant: .frosted)
    }
}
