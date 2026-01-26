import Foundation
import Combine

enum WebSocketEvent {
    case consoleOutput(String)
    case stats(String) // JSON string
    case status(String)
    case installOutput(String)
    case daemonError(String)
    case connected
    case disconnected
}

class WebSocketClient: NSObject, URLSessionWebSocketDelegate {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var isConnected = false
    
    // Subject to publish events
    let eventSubject = PassthroughSubject<WebSocketEvent, Never>()
    
    func connect(url: URL, token: String) {
        disconnect()
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // Origin is often required by Pterodactyl Wings
        request.addValue(url.absoluteString, forHTTPHeaderField: "Origin") 
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Authenticate immediately upon connection if needed, 
        // usually Pterodactyl expects {"event":"auth","args":["token"]}
        sendAuth(token: token)
        
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        eventSubject.send(.disconnected)
    }
    
    func sendCommand(_ command: String) {
        let message = "{\"event\":\"send\",\"args\":[\"\(command)\"]}"
        sendString(message)
    }
    
    func sendPowerAction(_ signal: String) {
         let message = "{\"event\":\"set state\",\"args\":[\"\(signal)\"]}"
         sendString(message)
    }
    
    private func sendAuth(token: String) {
        let message = "{\"event\":\"auth\",\"args\":[\"\(token)\"]}"
        sendString(message)
    }
    
    private func sendString(_ message: String) {
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket sending error: \(error)")
            }
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self.eventSubject.send(.disconnected)
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveMessage() // Continue listening
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        // Simple parsing of Pterodactyl JSON format
        // Expected format: {"event":"name", "args":["..."]}
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let event = json["event"] as? String,
              let args = json["args"] as? [String] else {
            // Check for jwt error or other formats
            return
        }
        
        let content = args.first ?? ""
        
        switch event {
        case "auth success":
            isConnected = true
            eventSubject.send(.connected)
        case "console output":
            eventSubject.send(.consoleOutput(content))
        case "stats":
            eventSubject.send(.stats(content))
        case "status":
            eventSubject.send(.status(content))
        case "install output":
            eventSubject.send(.installOutput(content))
        default:
            break
        }
    }
}
