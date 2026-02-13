import Foundation

enum PterodactylError: Error, LocalizedError {
    case invalidURL
    case serializationError
    case apiError(Int, String) // Code, Message
    case networkError(Error)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL configuration."
        case .serializationError: return "Failed to parse response."
        case .apiError(let code, let message): return "API Error \(code): \(message)"
        case .networkError(let error): return "Network Error: \(error.localizedDescription)"
        case .unauthorized: return "Unauthorized. Check API key."
        }
    }
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
        
        var components = URLComponents(url: baseURL.appendingPathComponent("api/client"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "include", value: "allocations")]
        
        var request = URLRequest(url: components.url!)
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

    func fetchResources(serverId: String) async throws -> ServerStats {
        guard let baseURL = baseURL, let apiKey = apiKey else {
            throw PterodactylError.invalidURL
        }
        
        // Correct endpoint: /api/client/servers/{id}/resources
        let endpoint = baseURL.appendingPathComponent("api/client/servers/\(serverId)/resources")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                // If 409 conflict (server installing/transferring), return default empty stats? Or throw.
                // Pterodactyl returns 409 if server is installing.
                if code == 409 {
                    throw PterodactylError.apiError(code, "Server is installing/transferring")
                }
                throw PterodactylError.apiError(code, "Failed to fetch resources")
            }
            
            let decoded = try JSONDecoder().decode(ServerStatsResponse.self, from: data)
            return decoded.attributes
        } catch {
            throw PterodactylError.networkError(error)
        }
    }

    func listFiles(serverId: String, directory: String = "/") async throws -> [FileAttributes] {
        guard let baseURL = baseURL, let apiKey = apiKey else {
            throw PterodactylError.invalidURL
        }
        
        // Handle URL encoding for directory path
        guard var components = URLComponents(url: baseURL.appendingPathComponent("api/client/servers/\(serverId)/files/list"), resolvingAgainstBaseURL: true) else {
            throw PterodactylError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "directory", value: directory)]
        
        guard let finalURL = components.url else { throw PterodactylError.invalidURL }
        var request = URLRequest(url: finalURL)
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
    
    func createBackup(serverId: String, name: String? = nil, ignoredFiles: [String] = []) async throws -> BackupAttributes {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/backups")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if !ignoredFiles.isEmpty { body["ignored"] = ignoredFiles.joined(separator: "\n") }
        
        if !body.isEmpty {
           request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to create backup")
        }
        
        let decoded = try JSONDecoder().decode(BackupData.self, from: data)
        return decoded.attributes
    }
    
    func deleteBackup(serverId: String, uuid: String) async throws {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/backups/\(uuid)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to delete backup")
        }
    }
    
    func getBackupDownloadUrl(serverId: String, uuid: String) async throws -> URL {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/backups/\(uuid)/download-url")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to get download URL")
        }
        
        struct DownloadResponse: Codable {
            let attributes: DownloadAttributes
        }
        struct DownloadAttributes: Codable {
            let url: String
        }
        
        let decoded = try JSONDecoder().decode(DownloadResponse.self, from: data)
        guard let downloadURL = URL(string: decoded.attributes.url) else {
             throw PterodactylError.serializationError
        }
        return downloadURL
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
        
        guard var components = URLComponents(url: baseURL.appendingPathComponent("api/client/servers/\(serverId)/files/contents"), resolvingAgainstBaseURL: true) else {
             throw PterodactylError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "file", value: filePath)]
        
        // WORKAROUND: Some Pterodactyl panels (Nginx) reject encoded slashes (%2F) in query params.
        // We manually revert them to "/" in the query string.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "%2F", with: "/")
        
        guard let finalURL = components.url else { throw PterodactylError.invalidURL }
        print("📂 PterodactylClient: Get File URL: \(finalURL)")
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            print("❌ PterodactylClient: Failed to read file '\(filePath)'. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0). Body: \(body)")
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to read file: \(body)")
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            throw PterodactylError.serializationError
        }
        
        return content
    }
    
    func writeFileContent(serverId: String, filePath: String, content: String) async throws {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        guard var components = URLComponents(url: baseURL.appendingPathComponent("api/client/servers/\(serverId)/files/write"), resolvingAgainstBaseURL: true) else {
             throw PterodactylError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "file", value: filePath)]
        
        // WORKAROUND: Unescape slashes for compatibility
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "%2F", with: "/")
        
        guard let finalURL = components.url else { throw PterodactylError.invalidURL }
        print("📝 PterodactylClient: Write File URL: \(finalURL)")
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = content.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            print("❌ PterodactylClient: Failed to write file '\(filePath)'. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0). Body: \(body)")
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to write file: \(body)")
        }
    }

    func compressFiles(serverId: String, root: String, files: [String]) async throws -> FileAttributes {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/files/compress")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Ensure root has trailing slash if needed? API expects root path.
        // files array is filenames relative to root.
        
        let body: [String: Any] = [
            "root": root,
            "files": files
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
             throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to compress files")
        }
        
        let decoded = try JSONDecoder().decode(PterodactylFile.self, from: data)
        return decoded.attributes
    }
    
    func decompressFile(serverId: String, root: String, file: String) async throws {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/files/decompress")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "root": root,
            "file": file
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
             throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to decompress file")
        }
    }

    // Placeholder to validate connection
    func validateConnection() async throws -> Bool {
        _ = try await fetchServers()
        return true
    }
    // fetchResources was already defined above
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
    
    // MARK: - Application API (Admin Only)
    
    /// Check if the API key has admin (Application API) access
    func checkAdminAccess() async -> Bool {
        guard let baseURL = baseURL, let apiKey = apiKey else { return false }
        
        let url = baseURL.appendingPathComponent("api/application/users")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200...299).contains(http.statusCode)
            }
            return false
        } catch {
            return false
        }
    }
    
    /// Fetch users (Application API)
    func fetchApplicationUsers(filter: String? = nil) async throws -> [ApplicationUser] {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let components = URLComponents(url: baseURL.appendingPathComponent("api/application/users"), resolvingAgainstBaseURL: true)!
        if let filter = filter, !filter.isEmpty {
            // Primitive filter query support
            // Pterodactyl uses filter[email]=...
            // For now just pass generic query items if needed, or just list all
        }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to fetch application users")
        }
        
        struct AppUserResponse: Codable {
            let data: [AppUserData]
        }
        struct AppUserData: Codable {
            let attributes: ApplicationUser
        }
        
        let decoded = try JSONDecoder().decode(AppUserResponse.self, from: data)
        return decoded.data.map { $0.attributes }
    }
    
    /// Fetch available nodes for server creation (Application API)
    func fetchNodes() async throws -> [NodeAttributes] {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/application/nodes")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to fetch nodes")
        }
        
        let decoded = try JSONDecoder().decode(NodeListResponse.self, from: data)
        return decoded.data.map { $0.attributes }
    }
    
    /// Fetch eggs (game templates) for a nest (Application API)
    func fetchEggs(nestId: Int) async throws -> [EggAttributes] {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        var components = URLComponents(url: baseURL.appendingPathComponent("api/application/nests/\(nestId)/eggs"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "include", value: "variables")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to fetch eggs")
        }
        
        let decoded = try JSONDecoder().decode(EggListResponse.self, from: data)
        return decoded.data.map { $0.attributes }
    }
    
    /// Fetch nests (categories) (Application API)
    func fetchNests() async throws -> [NestAttributes] {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/application/nests")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to fetch nests")
        }
        
        let decoded = try JSONDecoder().decode(NestListResponse.self, from: data)
        return decoded.data.map { $0.attributes }
    }
    
    /// Fetch available allocations for a node (Application API)
    func fetchApplicationAllocations(nodeId: Int) async throws -> [ApplicationAllocation] {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        var components = URLComponents(url: baseURL.appendingPathComponent("api/application/nodes/\(nodeId)/allocations"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "filter[server_id]", value: "0")] // Only unassigned
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to fetch allocations")
        }
        
        let decoded = try JSONDecoder().decode(ApplicationAllocationResponse.self, from: data)
        return decoded.data.map { $0.attributes }
    }

    // MARK: - Application Server Management
    
    /// Fetch all servers (Application API)
    func fetchApplicationServers(page: Int = 1) async throws -> [ApplicationServerAttributes] {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        var components = URLComponents(url: baseURL.appendingPathComponent("api/application/servers"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "page", value: "\(page)")]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to fetch application servers")
        }
        
        let decoded = try JSONDecoder().decode(ApplicationServerListResponse.self, from: data)
        return decoded.data.map { $0.attributes }
    }

    func createNest(name: String, description: String, author: String) async throws -> NestAttributes {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/application/nests")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": name,
            "description": description,
            "author": author
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to create nest")
        }
        
        let decoded = try JSONDecoder().decode(NestData.self, from: data)
        return decoded.attributes
    }
    
    func createEgg(nestId: Int, name: String, description: String, dockerImage: String, startup: String, config: [String: Any], scripts: [String: Any], author: String) async throws -> EggAttributes {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/application/nests/\(nestId)/eggs")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Ensure scripts and config are properly nested
        // The API expects 'docker_images' as a map or array?
        // AgentEggDefinition.dockerImage is a string. API expects 'docker_images' map { "actual": "display" } usually.
        // Let's wrap the dockerImage.
        
        let body: [String: Any] = [
            "name": name,
            "description": description,
            "docker_image": dockerImage, // Deprecated but often used, or use docker_images
            "docker_images": [dockerImage: dockerImage], // Valid map
            "startup": startup,
            "config": config,
            "scripts": scripts,
            "author": author
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (201...299).contains(http.statusCode) else {
             // Print response body for debugging if possible, but localized error handles it
             if let str = String(data: data, encoding: .utf8) {
                 print("Create Egg Error Body: \(str)")
             }
             throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to create egg")
        }
        
        let decoded = try JSONDecoder().decode(EggData.self, from: data)
        return decoded.attributes
    }
    
    func createEggVariable(nestId: Int, eggId: Int, name: String, description: String, envVariable: String, defaultValue: String, rules: String, userViewable: Bool, userEditable: Bool) async throws {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/application/nests/\(nestId)/eggs/\(eggId)/variables")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": name,
            "description": description,
            "env_variable": envVariable,
            "default_value": defaultValue,
            "user_viewable": userViewable,
            "user_editable": userEditable,
            "rules": rules
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
             if let str = String(data: data, encoding: .utf8) {
                 print("Create Variable Error Body: \(str)")
             }
             throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to create variable \(envVariable)")
        }
    }
    
    /// Create a new server (Application API)
    func createServer(
        name: String,
        userId: Int,
        eggId: Int,
        dockerImage: String,
        startup: String,
        environment: [String: String],
        limits: ServerLimits,
        featureLimits: FeatureLimits,
        allocationId: Int
    ) async throws -> ApplicationServerAttributes {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/application/servers")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": name,
            "user": userId,
            "egg": eggId,
            "docker_image": dockerImage,
            "startup": startup,
            "environment": environment,
            "limits": [
                "memory": limits.memory ?? 1024,
                "swap": limits.swap ?? 0,
                "disk": limits.disk ?? 5120,
                "io": limits.io ?? 500,
                "cpu": limits.cpu ?? 100
            ],
            "feature_limits": [
                "databases": featureLimits.databases ?? 0,
                "allocations": featureLimits.allocations ?? 1,
                "backups": featureLimits.backups
            ],
            "allocation": [
                "default": allocationId
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            if let str = String(data: data, encoding: .utf8) {
                print("Create Server Error: \(str)")
            }
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to create server")
        }
        
        let decoded = try JSONDecoder().decode(ApplicationServerResponse.self, from: data)
        return decoded.attributes
    }

    
    /// Fetch current user info to get user ID  
    func fetchCurrentUser() async throws -> UserInfo {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/account")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to fetch user info")
        }
        
        let decoded = try JSONDecoder().decode(UserInfoResponse.self, from: data)
        return decoded.attributes
    }
    func updateStartupVariable(serverId: String, key: String, value: String) async throws -> StartupVariable {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/startup/variable")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "key": key,
            "value": value
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
             throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to update variable")
        }
        
        let decoded = try JSONDecoder().decode(StartupData.self, from: data)
        return decoded.attributes
    }

    // MARK: - Extended File Management
    
    func deleteFiles(serverId: String, root: String, files: [String]) async throws {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/files/delete")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "root": root,
            "files": files
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
             throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to delete files")
        }
    }
    
    func renameFile(serverId: String, root: String, files: [(from: String, to: String)]) async throws {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/files/rename")
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "root": root,
            "files": files.map { ["from": $0.from, "to": $0.to] }
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
             throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to rename file")
        }
    }
    
    func createDirectory(serverId: String, root: String, name: String) async throws {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/files/create-folder")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "root": root,
            "name": name
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
             throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to create directory")
        }
    }
    
    func reinstallServer(serverId: String) async throws {
        guard let baseURL = baseURL, let apiKey = apiKey else { throw PterodactylError.invalidURL }
        
        // Pterodactyl API: POST /api/client/servers/{id}/settings/reinstall
        let url = baseURL.appendingPathComponent("api/client/servers/\(serverId)/settings/reinstall")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PterodactylError.apiError((response as? HTTPURLResponse)?.statusCode ?? 0, "Failed to reinstall server")
        }
    }
}
