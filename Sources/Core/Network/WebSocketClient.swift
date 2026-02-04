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
    static let shared = WebSocketClient()
    
    enum ConnectionStatus {
        case connected
        case disconnected
    }
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var isConnected = false
    
    // Subject to publish events
    private let eventSubject = PassthroughSubject<WebSocketEvent, Never>()
    
    // Public publisher
    var eventPublisher: AnyPublisher<WebSocketEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    func connect(url: URL, token: String, origin: String? = nil) {
        disconnect()
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Use provided origin (Panel URL) or fallback
        if let origin = origin {
            let sanitizedOrigin = origin.trimmingCharacters(in: .init(charactersIn: "/"))
            request.addValue(sanitizedOrigin, forHTTPHeaderField: "Origin")
        } else if let host = url.host {
            request.addValue("https://\(host)", forHTTPHeaderField: "Origin")
        } else {
             request.addValue(url.absoluteString, forHTTPHeaderField: "Origin")
        }
        
        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Authenticate immediately
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
        // Pterodactyl Wings expects "send command" event
        let payload: [String: Any] = [
            "event": "send command",
            "args": [command]
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let message = String(data: data, encoding: .utf8) {
            print("WebSocket sending: \(message)")
            sendString(message)
        }
    }
    
    func sendPowerAction(_ signal: String) {
         let message = "{\"event\":\"set state\",\"args\":[\"\(signal)\"]}"
         sendString(message)
    }
    
    func requestLogs() {
        // Request console history
        let message = "{\"event\":\"send logs\",\"args\":[null]}"
        print("WebSocket requesting logs: \(message)")
        sendString(message)
    }
    
    private func sendAuth(token: String) {
        let message = "{\"event\":\"auth\",\"args\":[\"\(token)\"]}"
        sendString(message)
    }
    
    private func sendString(_ message: String) {
        guard let task = webSocketTask else {
            print("WebSocket Error: No active connection")
            return
        }
        let wsMessage = URLSessionWebSocketTask.Message.string(message)
        task.send(wsMessage) { error in
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
        // Fallback or debug for non-standard frames
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let event = json["event"] as? String,
              let args = json["args"] as? [Any] else {
            // Check for potential error messages sent as plain text or different format
            if text.lowercased().contains("jwt") || text.lowercased().contains("error") {
                 eventSubject.send(.consoleOutput("System Error: \(text)"))
            }
            return
        }
        
        switch event {
        case "auth success":
            isConnected = true
            eventSubject.send(.connected)
            // Request console history immediately upon auth
            requestLogs()
        case "console output":
            // Handle both single string and array of strings (history often comes as array)
            if let lines = args as? [String] {
                for line in lines {
                    let clean = filterAnsiCodes(line)
                    eventSubject.send(.consoleOutput(clean))
                }
            } else if let line = args.first as? String {
                let clean = filterAnsiCodes(line)
                eventSubject.send(.consoleOutput(clean))
            }
        case "stats":
            let content = (args.first as? String) ?? ""
            eventSubject.send(.stats(content))
        case "status":
            let content = (args.first as? String) ?? ""
            eventSubject.send(.status(content))
        case "install output":
            let content = (args.first as? String) ?? ""
            eventSubject.send(.installOutput(content))
        default:
            break
        }
    }
    
    private func filterAnsiCodes(_ text: String) -> String {
        // More robust ANSI regex
        let ansiPattern = #"\\u001B\[[0-9;]*[a-zA-Z]"#
        if let regex = try? NSRegularExpression(pattern: ansiPattern, options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        }
        return text
    }
}
