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
    
    func getPanelURL() -> URL? { baseURL }
    
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

    func listFiles(serverId: String, directory: String = "/") async throws -> [FileAttributes] {
        guard let baseURL = baseURL, let apiKey = apiKey else {
            throw PterodactylError.invalidURL
        }
        
        // Handle URL encoding for directory path
        var components = URLComponents(url: baseURL.appendingPathComponent("api/client/servers/\(serverId)/files/list"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "directory", value: directory)]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to list files")
            }
            
            let decoded = try JSONDecoder().decode(FileListResponse.self, from: data)
            return decoded.data.map { $0.attributes }
        } catch {
             throw PterodactylError.networkError(error)
        }
    }
    
    func fetchAllocations(serverId: String) async throws -> [AllocationAttributes] {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/network/allocations")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AllocationResponse.self, from: data)
        return response.data.map { $0.attributes }
    }
    
    func sendPowerSignal(serverId: String, signal: String) async throws {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/power")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["signal": signal]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to send power signal")
        }
    }
    
    func fetchBackups(serverId: String) async throws -> [BackupAttributes] {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/backups")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(BackupResponse.self, from: data)
        return response.data.map { $0.attributes }
    }
    
    func fetchStartupVariables(serverId: String) async throws -> [StartupVariable] {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/startup")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(StartupResponse.self, from: data)
        return response.data.map { $0.attributes }
    }
    
    func getFileContent(serverId: String, filePath: String) async throws -> String {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        var components = URLComponents(url: baseURL.appendingPathComponent("api/client/servers/\(serverId)/files/contents"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "file", value: filePath)]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
             throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to read file")
        }
        
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    func writeFileContent(serverId: String, filePath: String, content: String) async throws {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        // Use 'write' endpoint which usually takes raw body or specific file param
        // Pterodactyl API: POST /files/write?file=...
        var components = URLComponents(url: baseURL.appendingPathComponent("api/client/servers/\(serverId)/files/write"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "file", value: filePath)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("text/plain", forHTTPHeaderField: "Content-Type") // Raw body usually
        
        request.httpBody = content.data(using: .utf8)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
             throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to save file")
        }
    }

    // Placeholder to validate connection
    func validateConnection() async throws -> Bool {
        _ = try await fetchServers()
        return true
    }
    func fetchResources(serverId: String) async throws -> ServerStats {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/resources")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
             throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to fetch resources")
        }
        
        let decoded = try JSONDecoder().decode(ServerStatsResponse.self, from: data)
        return decoded.attributes
    }
    // MARK: - New Features
    func fetchDatabases(serverId: String) async throws -> [DatabaseAttributes] {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/databases")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(DatabaseResponse.self, from: data)
        return response.data.map { $0.attributes }
    }
    
    func fetchSchedules(serverId: String) async throws -> [ScheduleAttributes] {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/schedules")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ScheduleResponse.self, from: data)
        return response.data.map { $0.attributes }
    }
    
    func fetchUsers(serverId: String) async throws -> [SubuserAttributes] {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/users")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(SubuserResponse.self, from: data)
        return response.data.map { $0.attributes }
    }
    // MARK: - API Keys
    func fetchApiKeys() async throws -> [ApiKeyAttributes] {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        let url = baseURL.appendingPathComponent("api/client/account/api-keys")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ApiKeyResponse.self, from: data)
        return response.data.map { $0.attributes }
    }
    
    func createApiKey(description: String, allowedIps: [String]) async throws -> ApiKeyAttributes {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        let url = baseURL.appendingPathComponent("api/client/account/api-keys")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "description": description,
            "allowed_ips": allowedIps
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
             throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to create API key")
        }
        
        let decoded = try JSONDecoder().decode(ApiKeyData.self, from: data)
        return decoded.attributes
    }
    
    func deleteApiKey(identifier: String) async throws {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        let url = baseURL.appendingPathComponent("api/client/account/api-keys/\(identifier)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
             throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to delete API key")
        }
    }
}
