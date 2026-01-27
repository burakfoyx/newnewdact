import Foundation
import Combine

struct Account: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let name: String
    let url: String
    let apiKey: String
    var theme: AppTheme = .blue // Default theme
    var lowPowerMode: Bool = false
}

class AccountManager: ObservableObject {
    static let shared = AccountManager()
    
    @Published var accounts: [Account] = []
    @Published var activeAccount: Account? {
        didSet {
            if let account = activeAccount {
                // Configure shared client whenever active account changes
                Task {
                    await PterodactylClient.shared.configure(url: account.url, key: account.apiKey)
                }
                saveActiveAccountId()
            }
        }
    }
    
    private let keychain = KeychainHelper.standard
    private let accountsKey = "saved_accounts"
    private let activeAccountKey = "active_account_id"
    
    init() {
        loadAccounts()
    }
    
    func addAccount(name: String, url: String, key: String) {
        let newAccount = Account(name: name, url: url, apiKey: key)
        accounts.append(newAccount)
        saveAccounts()
        
        // If this is the first account, make it active
        if accounts.count == 1 {
            activeAccount = newAccount
        }
    }
    
    func removeAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        saveAccounts()
        
        if activeAccount?.id == id {
            activeAccount = accounts.first
        }
    }
    
    func switchToAccount(id: UUID) {
        if let account = accounts.first(where: { $0.id == id }) {
            activeAccount = account
        }
    }
    
    func updateAccount(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts()
            if activeAccount?.id == account.id {
                activeAccount = account
            }
        }
    }
    
    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            try? keychain.save(data, account: accountsKey)
        }
    }
    
    private func saveActiveAccountId() {
        if let id = activeAccount?.id.uuidString, let data = id.data(using: .utf8) {
            try? keychain.save(data, account: activeAccountKey)
        }
    }
    
    private func loadAccounts() {
        // Load Accounts
        if let data = keychain.read(account: accountsKey),
           let savedAccounts = try? JSONDecoder().decode([Account].self, from: data) {
            self.accounts = savedAccounts
        }
        
        // Load Active Account
        if let data = keychain.read(account: activeAccountKey),
           let idString = String(data: data, encoding: .utf8),
           let uuid = UUID(uuidString: idString),
           let account = accounts.first(where: { $0.id == uuid }) {
            self.activeAccount = account
        } else {
            // Fallback
            self.activeAccount = accounts.first
        }
    }
}
