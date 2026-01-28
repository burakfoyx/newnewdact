import SwiftUI
import Combine


struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    var limits: ServerLimits?
    
    var body: some View {
        VStack(spacing: 0) {
            // Stats Bar
            // Stats removed (displayed in header)

            
            // Logs
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.logs, id: \.self) { log in
                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                    .padding(.bottom, 60) // Extra padding for fade area
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Color.clear)
                .onChange(of: viewModel.logs.count) {
                    if let last = viewModel.logs.last {
                         withAnimation {
                             proxy.scrollTo(last, anchor: .bottom)
                         }
                    }
                }
            }
            
            // Input Area
            VStack {
                HStack(spacing: 12) {
                    // Connection Status / Reconnect
                    if !viewModel.isConnected {
                        Button(action: { viewModel.connect() }) {
                             Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.red)
                                .shadow(color: .red.opacity(0.5), radius: 5)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                         Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .shadow(color: .green, radius: 5)
                            .padding(.leading, 4)
                    }

                    TextField("Type a command...", text: $viewModel.inputCommand)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                        .tint(.blue)
                        .submitLabel(.send)
                        .onSubmit { viewModel.sendCommand() }
                    
                    Button(action: { viewModel.sendCommand() }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(
                                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .clipShape(Circle())
                            .shadow(color: .blue.opacity(0.4), radius: 4)
                    }
                }
                .padding(6)
                .padding(.horizontal, 6)
                .glassEffect(.regular, in: Capsule())
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .background(Color.clear)
        .navigationTitle("Console")
        .navigationBarTitleDisplayMode(.inline)
        // Toolbar removed to avoid duplication with ServerDetailView header
        .onAppear {
            viewModel.connect()
        }
        .onDisappear {
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
    @Published var logs: [String] = []
    @Published var inputCommand: String = ""
    @Published var isConnected = false
    @Published var stats: WebsocketResponse.Stats?
    @Published var state: String = "unknown"
    
    private var cancellables = Set<AnyCancellable>()
    
    init(serverId: String) {
        self.serverId = serverId
        self.logs.append("System: Console interface initialized.")
        setupSubscription()
    }
    
    private func setupSubscription() {
        cancellables.removeAll()
        
        WebSocketClient.shared.eventSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }
    

    
    func sendCommand() {
        guard !inputCommand.isEmpty else { return }
        
        if !isConnected {
            self.logs.append("System: Cannot send - Disconnected")
            return
        }
        
        let cmd = inputCommand
        self.logs.append("> \(cmd)") // Local echo
        WebSocketClient.shared.sendCommand(cmd)
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
                let details = try await PterodactylClient.shared.fetchWebsocketDetails(serverId: serverId)
                let panelURL = await PterodactylClient.shared.getPanelURL()
                
                WebSocketClient.shared.disconnect() // Ensure crisp state
                
                // Add token as query param too, some daemons need it
                
                WebSocketClient.shared.connect(
                    url: URL(string: details.url)!, 
                    token: details.token,
                    origin: panelURL?.absoluteString 
                )
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
            if logs.count > 100 { logs.removeFirst() }
            
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
