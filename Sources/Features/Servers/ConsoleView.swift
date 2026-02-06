import SwiftUI
import Combine


struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    var limits: ServerLimits?
    
    var body: some View {
        VStack(spacing: 0) {
            // Console glass container
            VStack(spacing: 0) {
                // Logs Area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(viewModel.logs.enumerated()), id: \.offset) { index, log in
                                Text(AnsiParser.parse(log))
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                    .id(index)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                    .defaultScrollAnchor(.bottom)
                    .onChange(of: viewModel.logs.count) { oldCount, newCount in
                        withAnimation {
                            proxy.scrollTo(newCount - 1, anchor: .bottom)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Separator line
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 0.5)
                
                // Input Area - simple inline design
                HStack(spacing: 12) {
                    // Connection indicator
                    if viewModel.isConnected {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .shadow(color: .green, radius: 4)
                    } else {
                        Button(action: { viewModel.connect() }) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .shadow(color: .red, radius: 4)
                        }
                    }
                    
                    // Command input
                    TextField("Type a command...", text: $viewModel.inputCommand)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .tint(.cyan)
                        .submitLabel(.send)
                        .onSubmit { viewModel.sendCommand() }
                    
                    // Send button
                    Button(action: { viewModel.sendCommand() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color.clear)
        .navigationTitle("Console")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar) // Hide Tab Bar
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true // Keep screen awake
            viewModel.connect()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false // Allow sleep
            viewModel.disconnect()
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let text: String
}

class ConsoleViewModel: ObservableObject {
    let serverId: String
    let serverLimits: ServerLimits?
    @Published var logs: [String] = []
    @Published var inputCommand: String = ""
    @Published var isConnected = false
    @Published var stats: WebsocketResponse.Stats?
    @Published var state: String = "unknown"
    
    private var cancellables = Set<AnyCancellable>()
    
    init(serverId: String, limits: ServerLimits? = nil) {
        self.serverId = serverId
        self.serverLimits = limits
        self.logs.append("System: Console interface initialized.")
        setupSubscription()
    }
    
    private func setupSubscription() {
        cancellables.removeAll()
        
        WebSocketClient.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }
    
    func sendCommand() {
        let command = inputCommand.trimmingCharacters(in: .whitespaces)
        guard !command.isEmpty else { return }
        
        WebSocketClient.shared.sendCommand(command)
        inputCommand = ""
    }
    
    func sendPowerAction(_ signal: String) {
        Task {
            // Use REST API for power actions as it's more reliable than websocket typically for these calls
            try? await PterodactylClient.shared.sendPowerSignal(serverId: serverId, signal: signal)
        }
    }
    
    func connect() {
        Task {
            do {
                await MainActor.run { self.logs.append("System: Authenticating with Pterodactyl...") }
                
                // Need both socket details and origin
                let (urlString, token) = try await PterodactylClient.shared.fetchWebsocketDetails(serverId: serverId)
                guard let socketURL = URL(string: urlString) else {
                    throw PterodactylError.invalidURL
                }
                guard let origin = await PterodactylClient.shared.getPanelURL() else {
                    throw PterodactylError.invalidURL
                }
                
                await MainActor.run { self.logs.append("System: Connecting to console...") }
                WebSocketClient.shared.connect(url: socketURL, token: token, origin: origin.absoluteString)
                
            } catch {
                await MainActor.run {
                    self.logs.append("System Error: Could not connect - \(error.localizedDescription)")
                }
            }
        }
    }
    
    func disconnect() {
        WebSocketClient.shared.disconnect()
    }
    
    private func handleEvent(_ event: WebSocketEvent) {
        // Failsafe: If receiving data, we are connected
        if !isConnected {
             switch event {
             case .consoleOutput, .stats, .status:
                 self.isConnected = true
             default: break
             }
        }
        
        switch event {
        case .consoleOutput(let log):
            self.logs.append(log)
            if logs.count > 1000 { logs.removeFirst() }
            
        case .stats(let statsJson):
             if let statsData = statsJson.data(using: .utf8),
                let stats = try? JSONDecoder().decode(WebsocketResponse.Stats.self, from: statsData) {
                 self.stats = stats
             }
             
        case .status(let status):
            self.state = status
            
        case .connected:
            self.isConnected = true
            self.logs.append("System: Connected! Loading console history...")
            // Request logs history after connection
            WebSocketClient.shared.requestLogs()
            
        case .disconnected:
            self.isConnected = false
            
        default:
            break
        }
    }
    

}
