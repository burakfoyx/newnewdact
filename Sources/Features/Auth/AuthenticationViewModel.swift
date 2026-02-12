import SwiftUI

enum KeyCheckState: Equatable {
    case idle
    case connecting
    case checkingPermissions
    case adminDetected
    case userDetected
    case failed(String)
}

class AuthenticationViewModel: ObservableObject {
    @Published var name: String = "My Panel"
    @Published var hostURL: String = ""
    @Published var apiKey: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false // Acts as "Success" trigger
    @Published var keyCheckState: KeyCheckState = .idle
    
    func login() async {
        guard !hostURL.isEmpty, !apiKey.isEmpty else {
            errorMessage = "Please enter Host URL and API Key"
            return
        }
        
        await MainActor.run { 
            isLoading = true
            errorMessage = nil 
            keyCheckState = .connecting
        }
        
        // Validate connection first using a temporary configuration
        let tempClient = PterodactylClient.shared
        await tempClient.configure(url: hostURL, key: apiKey)
        
        do {
            // Try Client API first
            var isValid = false
            var isAppKey = false
            
            do {
                isValid = try await tempClient.validateConnection()
            } catch {
                // If Client API fails, check if it's an Application Key
                print("Client API validation failed: \(error). Checking Application API...")
            }
            
            if !isValid {
                // Check Application API
                let appAccess = await tempClient.checkAdminAccess()
                if appAccess {
                    isValid = true
                    isAppKey = true
                }
            }
            
            if isValid {
                // Connection valid - now check for admin access
                await MainActor.run { keyCheckState = .checkingPermissions }
                
                // Wait a bit for visual effect
                try? await Task.sleep(nanoseconds: 800_000_000)
                
                // Check if this is an admin key
                let hasAdminAccess = isAppKey ? true : await tempClient.checkAdminAccess()
                
                await MainActor.run {
                    if hasAdminAccess {
                        keyCheckState = .adminDetected
                    } else {
                        keyCheckState = .userDetected
                    }
                }
                
                // Wait for animation
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                
                await MainActor.run {
                    AccountManager.shared.addAccount(
                        name: name, 
                        url: hostURL, 
                        key: apiKey, 
                        hasAdminAccess: hasAdminAccess
                    )
                    activeAccount = AccountManager.shared.activeAccount
                    isAuthenticated = true
                    isLoading = false
                    keyCheckState = .idle
                }
            } else {
                throw PterodactylError.apiError(401, "Invalid API Key or URL")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Connection failed: \(error.localizedDescription)"
                isLoading = false
                keyCheckState = .failed(error.localizedDescription)
            }
        }
    }
    
    // Explicit reference to activeAccount for some views if needed, purely helper
    private var activeAccount: Account?
}
