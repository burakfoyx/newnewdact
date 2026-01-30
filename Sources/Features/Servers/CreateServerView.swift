import SwiftUI

struct CreateServerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateServerViewModel()
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case serverName, memory, disk, cpu
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                    .ignoresSafeArea()
                    .onTapGesture {
                        focusedField = nil // Dismiss keyboard
                    }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Server Name
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Server Name", systemImage: "server.rack")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            TextField("My Minecraft Server", text: $viewModel.serverName)
                                .focused($focusedField, equals: .serverName)
                                .padding()
                                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Node Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Node", systemImage: "cpu")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            if viewModel.isLoadingNodes {
                                HStack {
                                    ProgressView().tint(.white)
                                    Text("Loading nodes...")
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                            } else if viewModel.nodes.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.orange)
                                    Text("No nodes available")
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                            } else {
                                Menu {
                                    ForEach(viewModel.nodes) { node in
                                        Button(node.name) {
                                            viewModel.selectedNode = node
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(viewModel.selectedNode?.name ?? "Select Node")
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                                    .contentShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        
                        // Nest (Category) Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Category", systemImage: "folder")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            if viewModel.isLoadingNests {
                                HStack {
                                    ProgressView().tint(.white)
                                    Text("Loading categories...")
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                            } else if viewModel.nests.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.orange)
                                    Text("No categories available")
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                            } else {
                                Menu {
                                    ForEach(viewModel.nests) { nest in
                                        Button(nest.name) {
                                            viewModel.selectedNest = nest
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(viewModel.selectedNest?.name ?? "Select Category")
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                                    .contentShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        
                        // Egg (Template) Selection
                        if viewModel.selectedNest != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Template", systemImage: "doc.text")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                
                                if viewModel.isLoadingEggs {
                                    HStack {
                                        ProgressView().tint(.white)
                                        Text("Loading templates...")
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                                } else if viewModel.eggs.isEmpty {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundStyle(.orange)
                                        Text("No templates available")
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                                } else {
                                    Menu {
                                        ForEach(viewModel.eggs) { egg in
                                            Button(egg.name) {
                                                viewModel.selectedEgg = egg
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Text(viewModel.selectedEgg?.name ?? "Select Template")
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Image(systemName: "chevron.down")
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                                        .contentShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }
                        
                        // Resources Section
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Resources", systemImage: "gauge")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            // Memory
                            ResourceInputSlider(
                                title: "Memory",
                                value: $viewModel.memory,
                                range: 128...16384,
                                step: 128,
                                unit: "MB",
                                icon: "memorychip",
                                focusedField: $focusedField,
                                field: .memory
                            )
                            
                            // Disk
                            ResourceInputSlider(
                                title: "Disk",
                                value: $viewModel.disk,
                                range: 512...102400,
                                step: 512,
                                unit: "MB",
                                icon: "internaldrive",
                                focusedField: $focusedField,
                                field: .disk
                            )
                            
                            // CPU
                            ResourceInputSlider(
                                title: "CPU",
                                value: $viewModel.cpu,
                                range: 10...400,
                                step: 10,
                                unit: "%",
                                icon: "cpu",
                                focusedField: $focusedField,
                                field: .cpu
                            )
                        }
                        .padding()
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
                        
                        // Error
                        if let error = viewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(error)
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Create Button
                        Button(action: {
                            focusedField = nil // Dismiss keyboard first
                            Task { await viewModel.createServer() }
                        }) {
                            if viewModel.isCreating {
                                HStack {
                                    ProgressView().tint(.white)
                                    Text("Creating Server...")
                                        .foregroundStyle(.white)
                                }
                            } else {
                                Label("Create Server", systemImage: "plus.circle.fill")
                                    .fontWeight(.bold)
                            }
                        }
                        .buttonStyle(LiquidButtonStyle())
                        .disabled(!viewModel.canCreate || viewModel.isCreating)
                        .opacity(viewModel.canCreate ? 1.0 : 0.5)
                    }
                    .padding()
                    .padding(.bottom, 50)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Create Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                }
            }
            .onChange(of: viewModel.serverCreated) { _, created in
                if created { dismiss() }
            }
            .task {
                await viewModel.loadInitialData()
            }
        }
    }
}

// MARK: - Resource Input Slider (with tappable text input)

struct ResourceInputSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let icon: String
    var focusedField: FocusState<CreateServerView.Field?>.Binding
    let field: CreateServerView.Field
    
    @State private var textValue: String = ""
    @State private var isEditing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .foregroundStyle(.white)
                Spacer()
                
                if isEditing {
                    HStack(spacing: 4) {
                        TextField("", text: $textValue)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused(focusedField, equals: field)
                            .onSubmit {
                                applyTextValue()
                            }
                        Text(unit)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                } else {
                    Button(action: {
                        textValue = String(Int(value))
                        isEditing = true
                        focusedField.wrappedValue = field
                    }) {
                        Text("\(Int(value)) \(unit)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(.blue)
                .onChange(of: value) { _, newValue in
                    if !isEditing {
                        textValue = String(Int(newValue))
                    }
                }
        }
        .onChange(of: focusedField.wrappedValue) { _, newFocus in
            if newFocus != field && isEditing {
                applyTextValue()
                isEditing = false
            }
        }
        .onAppear {
            textValue = String(Int(value))
        }
    }
    
    private func applyTextValue() {
        if let intValue = Int(textValue) {
            let clamped = min(max(Double(intValue), range.lowerBound), range.upperBound)
            let stepped = (clamped / step).rounded() * step
            value = stepped
            textValue = String(Int(stepped))
        }
        isEditing = false
    }
}

// MARK: - ViewModel

class CreateServerViewModel: ObservableObject {
    @Published var serverName = ""
    @Published var nodes: [NodeAttributes] = []
    @Published var nests: [NestAttributes] = []
    @Published var eggs: [EggAttributes] = []
    @Published var selectedNode: NodeAttributes?
    @Published var selectedNest: NestAttributes? {
        didSet {
            if let nest = selectedNest {
                Task { await loadEggs(for: nest.id) }
            }
        }
    }
    @Published var selectedEgg: EggAttributes?
    @Published var memory: Double = 1024
    @Published var disk: Double = 5120
    @Published var cpu: Double = 100
    @Published var isLoadingNodes = false
    @Published var isLoadingNests = false
    @Published var isLoadingEggs = false
    @Published var isCreating = false
    @Published var errorMessage: String?
    @Published var serverCreated = false
    
    var canCreate: Bool {
        !serverName.isEmpty && 
        selectedNode != nil && 
        selectedEgg != nil
    }
    
    func loadInitialData() async {
        await loadNodes()
        await loadNests()
    }
    
    func loadNodes() async {
        await MainActor.run { isLoadingNodes = true }
        do {
            let fetched = try await PterodactylClient.shared.fetchNodes()
            await MainActor.run {
                nodes = fetched
                isLoadingNodes = false
            }
        } catch let error as PterodactylError {
            await MainActor.run {
                errorMessage = formatError(error, context: "nodes")
                isLoadingNodes = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load nodes: \(error.localizedDescription)"
                isLoadingNodes = false
            }
        }
    }
    
    func loadNests() async {
        await MainActor.run { isLoadingNests = true }
        do {
            let fetched = try await PterodactylClient.shared.fetchNests()
            await MainActor.run {
                nests = fetched
                isLoadingNests = false
            }
        } catch let error as PterodactylError {
            await MainActor.run {
                errorMessage = formatError(error, context: "categories")
                isLoadingNests = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load categories: \(error.localizedDescription)"
                isLoadingNests = false
            }
        }
    }
    
    func loadEggs(for nestId: Int) async {
        await MainActor.run { 
            isLoadingEggs = true 
            eggs = []
            selectedEgg = nil
        }
        do {
            let fetched = try await PterodactylClient.shared.fetchEggs(nestId: nestId)
            await MainActor.run {
                eggs = fetched
                isLoadingEggs = false
            }
        } catch let error as PterodactylError {
            await MainActor.run {
                errorMessage = formatError(error, context: "templates")
                isLoadingEggs = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load templates: \(error.localizedDescription)"
                isLoadingEggs = false
            }
        }
    }
    
    func createServer() async {
        guard let node = selectedNode,
              let egg = selectedEgg else { return }
        
        await MainActor.run { 
            isCreating = true
            errorMessage = nil
        }
        
        do {
            // Get allocations for the node
            let allocations = try await PterodactylClient.shared.fetchApplicationAllocations(nodeId: node.id)
            guard let allocation = allocations.first(where: { !$0.assigned }) else {
                await MainActor.run {
                    errorMessage = "No available allocations on this node. Please create allocations in the panel first."
                    isCreating = false
                }
                return
            }
            
            // Get current user
            let user = try await PterodactylClient.shared.fetchCurrentUser()
            
            // Create server
            let limits = ServerLimits(
                memory: Int(memory),
                swap: 0,
                disk: Int(disk),
                io: 500,
                cpu: Int(cpu),
                threads: nil
            )
            
            let featureLimits = FeatureLimits(databases: 0, allocations: 1, backups: 3)
            
            _ = try await PterodactylClient.shared.createServer(
                name: serverName,
                userId: user.id,
                eggId: egg.id,
                dockerImage: egg.dockerImage,
                startup: egg.startup,
                environment: [:], // Would need to fetch egg variables for real implementation
                limits: limits,
                featureLimits: featureLimits,
                allocationId: allocation.id
            )
            
            await MainActor.run {
                isCreating = false
                serverCreated = true
            }
        } catch let error as PterodactylError {
            await MainActor.run {
                errorMessage = formatError(error, context: "server creation")
                isCreating = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create server: \(error.localizedDescription)"
                isCreating = false
            }
        }
    }
    
    private func formatError(_ error: PterodactylError, context: String) -> String {
        switch error {
        case .apiError(let code, let message):
            if code == 0 {
                return "Network error during \(context). Please check your connection."
            } else if code == 403 {
                return "Access denied. Your API key doesn't have permission for \(context)."
            } else if code == 404 {
                return "Resource not found during \(context)."
            } else if code == 422 {
                return "Invalid data for \(context). \(message)"
            } else {
                return "Error \(code) during \(context): \(message)"
            }
        case .unauthorized:
            return "Unauthorized. Please check your API key."
        case .invalidURL:
            return "Invalid panel URL."
        case .networkError(let underlyingError):
            return "Network error: \(underlyingError.localizedDescription)"
        case .serializationError:
            return "Failed to parse response from server."
        }
    }
}
