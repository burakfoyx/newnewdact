import SwiftUI

class AuthenticationViewModel: ObservableObject {
    @Published var hostURL: String = ""
    @Published var apiKey: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    
    private let keychain = KeychainHelper.standard
    private let accountKey = "current_session"
    
    init() {
        loadCredentials()
    }
    
    func login() async {
        guard !hostURL.isEmpty, !apiKey.isEmpty else {
            errorMessage = "Please enter both Host URL and API Key"
            return
        }
        
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        let client = PterodactylClient.shared
        await client.configure(url: hostURL, key: apiKey)
        
        do {
            let isValid = try await client.validateConnection()
            if isValid {
                saveCredentials()
                await MainActor.run {
                    isAuthenticated = true
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Connection failed: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func saveCredentials() {
        // Save as a JSON blob or specific fields
        let credentials = ["url": hostURL, "key": apiKey]
        if let data = try? JSONEncoder().encode(credentials) {
            try? keychain.save(data, account: accountKey)
        }
    }
    
    private func loadCredentials() {
        if let data = keychain.read(account: accountKey),
           let credentials = try? JSONDecoder().decode([String: String].self, from: data),
           let cachedURL = credentials["url"],
           let cachedKey = credentials["key"] {
            self.hostURL = cachedURL
            self.apiKey = cachedKey
            // Optionally auto-login here
        }
    }
}
