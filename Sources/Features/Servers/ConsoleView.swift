import SwiftUI
import Combine


struct ConsoleView: View {
    let serverId: String
    @StateObject private var viewModel: ConsoleViewModel
    
    init(serverId: String) {
        self.serverId = serverId
        _viewModel = StateObject(wrappedValue: ConsoleViewModel(serverId: serverId))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Terminal Output
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.logs) { log in
                        Text(log.text)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .background(Color.black.opacity(0.9))
            .defaultScrollAnchor(.bottom)
            
            // Input
            HStack {
                TextField("Type a command...", text: $viewModel.inputCommand)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                
                Button(action: viewModel.sendCommand) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
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
    @Published var logs: [LogEntry] = []
    @Published var inputCommand: String = ""
    @Published var isConnected = false
    
    private let wsClient = WebSocketClient()
    private var cancellables = Set<AnyCancellable>()
    
    init(serverId: String) {
        self.serverId = serverId
        
        wsClient.eventSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
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
