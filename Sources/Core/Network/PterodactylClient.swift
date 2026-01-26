import Foundation

enum PterodactylError: Error {
    case invalidURL
    case serializationError
    case apiError(Int, String) // Code, Message
    case networkError(Error)
    case unauthorized
}

actor PterodactylClient {
    static let shared = PterodactylClient()
    
    private var baseURL: URL?
    private var apiKey: String?
    
    private init() {}
    
    func configure(url: String, key: String) {
        self.baseURL = URL(string: url)
        self.apiKey = key
    }
    
    func fetchServers() async throws -> [ServerAttributes] {
        guard let baseURL = baseURL, let apiKey = apiKey else {
            throw PterodactylError.invalidURL
        }
        
        let endpoint = baseURL.appendingPathComponent("api/client")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PterodactylError.networkError(URLError(.badServerResponse))
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 { throw PterodactylError.unauthorized }
                throw PterodactylError.apiError(httpResponse.statusCode, "Server error")
            }
            
            let decodedResponse = try JSONDecoder().decode(ServerListResponse.self, from: data)
            return decodedResponse.data.map { $0.attributes }
            
        } catch {
            throw PterodactylError.networkError(error)
        }
    }
    
    func fetchWebsocketDetails(serverId: String) async throws -> (url: String, token: String) {
        guard let baseURL = baseURL, let apiKey = apiKey else {
            throw PterodactylError.invalidURL
        }
        
        let endpoint = baseURL.appendingPathComponent("api/client/servers/\(serverId)/websocket")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
             guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to get websocket credentials")
            }
            
            let decoded = try JSONDecoder().decode(WebsocketResponse.self, from: data)
            return (decoded.data.socket, decoded.data.token)
        } catch {
            throw PterodactylError.networkError(error)
        }
    }
    
    // Placeholder to validate connection
    func validateConnection() async throws -> Bool {
        _ = try await fetchServers()
        return true
    }
}
