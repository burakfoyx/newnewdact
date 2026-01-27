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
        
        WebSocketClient.shared.eventSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
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
        Task {
            if let details = try? await PterodactylClient.shared.fetchWebsocketDetails(serverId: serverId) {
                WebSocketClient.shared.connect(url: URL(string: details.url)!, token: details.token)
            }
        }
    }
    
    func disconnect() {
        WebSocketClient.shared.disconnect()
    }
    
    func sendCommand() {
        guard !inputCommand.isEmpty else { return }
        WebSocketClient.shared.sendCommand(inputCommand)
        inputCommand = ""
    }
    
    func sendPowerAction(_ signal: String) {
        wsClient.sendPowerAction(signal)
    }
    
    private func handleEvent(_ event: WebSocketEvent) {
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
            
        case .disconnected:
            self.isConnected = false
            
        default:
            break
        }
    }
