import SwiftUI

struct SettingsView: View {
    @ObservedObject var accountManager = AccountManager.shared
    @State private var showLogin = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Active Account") {
                    if let active = accountManager.activeAccount {
                        AccountRow(account: active, isActive: true)
                    } else {
                        Text("No active account")
                    }
                }
                
                Section("All Accounts") {
                    ForEach(accountManager.accounts) { account in
                        if account.id != accountManager.activeAccount?.id {
                            AccountRow(account: account, isActive: false)
                                .onTapGesture {
                                    accountManager.switchToAccount(id: account.id)
                                }
                        }
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            let account = accountManager.accounts[index]
                            accountManager.removeAccount(id: account.id)
                        }
                    }
                    
                    Button {
                        showLogin = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Another Account")
                        }
                    }
                }
                
                // Appearance section removed as per "remove theme stuff" request
                /*
                Section("Appearance") {
                   ...
                }
                */
                
                Section {
                    Button(role: .destructive) {
                        if let id = accountManager.activeAccount?.id {
                            accountManager.removeAccount(id: id)
                        }
                    } label: {
                        Text("Logout Active Account")
                    }
                }
                
                Section {
                    Text("XYIdactyl v1.1.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Accounts")
            .sheet(isPresented: $showLogin) {
                AuthenticationView(isPresented: $showLogin)
            }
        }
    }
}

struct AccountRow: View {
    let account: Account
    let isActive: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(account.name)
                    .font(.headline)
                Text(account.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            
            // Theme Indicator
            Circle()
                .fill(LinearGradient(colors: account.theme.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 16, height: 16)
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Text("Select Theme")
            ForEach(AppTheme.allCases) { theme in
                Button {
                    var updatedAccount = account
                    updatedAccount.theme = theme
                    AccountManager.shared.updateAccount(updatedAccount)
                } label: {
                    Label(theme.rawValue, systemImage: "paintbrush")
                }
            }
        }
    }
}


struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
