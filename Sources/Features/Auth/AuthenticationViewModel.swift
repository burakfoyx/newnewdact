import SwiftUI

class AuthenticationViewModel: ObservableObject {
    @Published var name: String = "My Panel"
    @Published var hostURL: String = ""
    @Published var apiKey: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false // Acts as "Success" trigger
    
    func login() async {
        guard !hostURL.isEmpty, !apiKey.isEmpty else {
            errorMessage = "Please enter Host URL and API Key"
            return
        }
        
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        // Validate connection first using a temporary configuration
        let tempClient = PterodactylClient.shared // Ideally use a transient instance, but shared is fine since we configure it
        await tempClient.configure(url: hostURL, key: apiKey)
        
        do {
            let isValid = try await tempClient.validateConnection()
            if isValid {
                await MainActor.run {
                    AccountManager.shared.addAccount(name: name, url: hostURL, key: apiKey)
                    activeAccount = AccountManager.shared.activeAccount // Force update (hacky, but ensures view refreshes)
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
    
    // Explicit reference to activeAccount for some views if needed, purely helper
    private var activeAccount: Account?
}
