import SwiftUI

struct PanelListView: View {
    @ObservedObject var accountManager = AccountManager.shared
    @State private var showAddPanel = false
    @Binding var selectedTab: Int
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - same approach as AuthenticationView
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(accountManager.accounts) { account in
                            Button(action: {
                                accountManager.switchToAccount(id: account.id)
                                selectedTab = 2
                            }) {
                                PanelRow(account: account, isActive: accountManager.activeAccount?.id == account.id)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }
                .scrollContentBackground(.hidden)
                
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
            .navigationTitle("Panels")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
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
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
    }
}
