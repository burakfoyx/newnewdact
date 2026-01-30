import SwiftUI

struct PanelListView: View {
    @ObservedObject var accountManager = AccountManager.shared
    @State private var showAddPanel = false
    @Binding var selectedTab: Int
    @State private var panelToDelete: Account?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                if accountManager.accounts.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.system(size: 60))
                            .foregroundStyle(.white.opacity(0.5))
                        
                        Text("No Panels")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        
                        Text("Add your first Pterodactyl panel to get started")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        
                        Button(action: { showAddPanel = true }) {
                            Label("Add Panel", systemImage: "plus")
                                .fontWeight(.bold)
                        }
                        .buttonStyle(LiquidButtonStyle())
                        .padding(.horizontal, 60)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(accountManager.accounts) { account in
                            PanelRowItem(
                                account: account,
                                isActive: accountManager.activeAccount?.id == account.id,
                                onSelect: {
                                    accountManager.switchToAccount(id: account.id)
                                    selectedTab = 2
                                }
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let account = accountManager.accounts[index]
                                panelToDelete = account
                                showDeleteConfirmation = true
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    
                    // Floating Add Button
                    VStack {
                         Spacer()
                         HStack {
                             Spacer()
                             Button(action: { showAddPanel = true }) {
                                 Image(systemName: "plus")
                                     .font(.title2.bold())
                                     .foregroundStyle(.white)
                                     .frame(width: 56, height: 56)
                                     .glassEffect(.clear.interactive(), in: Circle())
                             }
                             .padding()
                         }
                    }
                }
            }
            .navigationTitle("Panels")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if !accountManager.accounts.isEmpty {
                    EditButton()
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showAddPanel) {
            AuthenticationView(isPresented: $showAddPanel)
        }
        .confirmationDialog(
            "Delete Panel",
            isPresented: $showDeleteConfirmation,
            presenting: panelToDelete
        ) { panel in
            Button("Delete \(panel.name)", role: .destructive) {
                accountManager.removeAccount(id: panel.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { panel in
            Text("Are you sure you want to remove \"\(panel.name)\"? This will remove the saved credentials.")
        }
    }
}

// MARK: - Panel Row Item

struct PanelRowItem: View {
    let account: Account
    let isActive: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(account.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        
                        if account.hasAdminAccess {
                            Text("ADMIN")
                                .font(.caption2.bold())
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(account.url)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(
                        color: isActive ? Color.blue.opacity(0.6) : Color.clear,
                        radius: isActive ? 12 : 0
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isActive ? Color.blue.opacity(0.8) : Color.white.opacity(0.1),
                        lineWidth: isActive ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
