import SwiftUI

struct PanelListView: View {
    @ObservedObject var accountManager = AccountManager.shared
    @State private var showAddPanel = false
    
    var body: some View {
        ZStack {
            LiquidBackgroundView()
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(accountManager.accounts) { account in
                        Button(action: {
                            accountManager.switchToAccount(id: account.id)
                        }) {
                            PanelRow(account: account, isActive: accountManager.activeAccount?.id == account.id)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Show server list preview for active account?
                        // Or just list panels. User says "Panels page... shows servers not the panels".
                        // So this list should show PANELS.
                    }
                    
                    Button(action: { showAddPanel = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Connect New Panel")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .glassEffect(.regular, in: Capsule())
                    }
                    .padding(.top)
                }
                .padding()
            }
        }
        .navigationTitle("Panels") // This title might be hidden if we hide nav bar, but TabView uses it?
        // Actually TabView titles are independent.
        .sheet(isPresented: $showAddPanel) {
            AuthenticationView(isPresented: $showAddPanel)
        }
    }
}

struct PanelRow: View {
    let account: Account
    let isActive: Bool
    
    var body: some View {
        GlassEffectContainer(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(account.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(account.url)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Spacer()
                
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .shadow(color: .green.opacity(0.5), radius: 5)
                } else {
                    Image(systemName: "arrow.right.circle")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding()
            .glassEffect(isActive ? .regular : .thin, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
    }
}
