import SwiftUI
import Combine


struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Stats Bar
            if let stats = viewModel.stats {
                HStack {
                    Label(stats.memory_bytes.formattedMemory, systemImage: "memorychip")
                    Spacer()
                    Label(stats.cpu_absolute.formattedCPU, systemImage: "cpu")
                }
                .font(.caption.monospaced())
                .padding(.horizontal)
                .padding(.top, 8)
                .foregroundStyle(.white.opacity(0.7))
            }
            
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
                }
                .onChange(of: viewModel.logs.count) {
                    if let last = viewModel.logs.last {
                         withAnimation {
                             proxy.scrollTo(last, anchor: .bottom)
                         }
                    }
                }
            }
            
            // Input
            HStack {
                TextField("Type a command...", text: $viewModel.command)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                
                Button(action: { viewModel.sendCommand() }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationTitle("Console")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Menu {
                        Button(action: { viewModel.sendPowerAction("start") }) {
                            Label("Start", systemImage: "play.fill")
                        }
                        Button(action: { viewModel.sendPowerAction("restart") }) {
                            Label("Restart", systemImage: "arrow.clockwise")
                        }
                        Button(action: { viewModel.sendPowerAction("stop") }) {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        Button(role: .destructive, action: { viewModel.sendPowerAction("kill") }) {
                            Label("Kill", systemImage: "flame.fill")
                        }
                    } label: {
                        Image(systemName: "power")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
            }
        }
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
        setupSubscription()
    }
    
    private func setupSubscription() {
        cancellables.removeAll()
        
        WebSocketClient.shared.messageSubject
            .receive(on: RunLoop.main) // Use RunLoop.main for MainActor equivalent in Combine
            .sink { [weak self] message in
                guard let self = self else { return }
                
                // Parse message
                // Pterodactyl sends {"event":"stats","args":["{...}"]}
                // or {"event":"status", "args":["running"]}
                // or {"event":"console output", "args":["log line"]}
                
                // NOTE: The actual message format from Wings is usually a JSON string that needs parsing.
                // Assuming WebSocketClient sends raw string or parsed object.
                // Let's assume raw string for now and parse carefully.
                
                self.handleMessage(message)
            }
            .store(in: &cancellables)
        
        WebSocketClient.shared.connectionStatusSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.isConnected = (status == .connected)
            }
            .store(in: &cancellables)
    }
    
    private func handleMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String,
              let args = json["args"] as? [Any] else { return }
              
        if event == "console output", let log = args.first as? String {
             self.logs.append(log)
             if logs.count > 100 { logs.removeFirst() }
        } else if event == "status", let state = args.first as? String {
             self.state = state
        } else if event == "stats", let statsStr = args.first as? String {
             // Stats usually come as a JSON string inside the array
             if let statsData = statsStr.data(using: .utf8),
                let stats = try? JSONDecoder().decode(WebsocketResponse.Stats.self, from: statsData) {
                 self.stats = stats
             }
        }
    }
    
    func sendCommand() {
        guard !command.isEmpty else { return }
        WebSocketClient.shared.sendCommand(command)
        command = ""
    }
    
    func sendPowerAction(_ signal: String) {
        Task {
            // Use REST API for power actions as it's more reliable than websocket typically for these calls
            try? await PterodactylClient.shared.sendPowerSignal(serverId: serverId, signal: signal)
        }
    }
    
    func connect() {
        // In a real implementation, we need to first fetch the WEBSOCKET DETAILS from the API
        // GET /api/client/servers/{uuid}/websocket
        // Then connect with that URL and Token.
        // For this demo, I'll simulate or assume we fetch it.
        // I will add a method to PterodactylClient to fetch websocket credentials
        
        Task {
            if let details = try? await PterodactylClient.shared.fetchWebsocketDetails(serverId: serverId) {
                wsClient.connect(url: URL(string: details.url)!, token: details.token)
            }
        }
    }
    
    func disconnect() {
        wsClient.disconnect()
    }
    
    func sendCommand() {
        guard !inputCommand.isEmpty else { return }
        wsClient.sendCommand(inputCommand)
        inputCommand = ""
    }
    
    func sendPowerAction(_ signal: String) {
        wsClient.sendPowerAction(signal)
    }
    
    private func handleEvent(_ event: WebSocketEvent) {
        switch event {
        case .consoleOutput(let text):
            // Strip ANSI codes if necessary, for now raw
            logs.append(LogEntry(text: text))
            if logs.count > 100 { logs.removeFirst() }
        case .connected:
            isConnected = true
        case .disconnected:
            isConnected = false
        default:
            break
        }
    }
}
