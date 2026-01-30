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
                // Background - same approach as AuthenticationView
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
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(accountManager.accounts) { account in
                                PanelCard(
                                    account: account,
                                    isActive: accountManager.activeAccount?.id == account.id,
                                    onSelect: {
                                        accountManager.switchToAccount(id: account.id)
                                        selectedTab = 2
                                    },
                                    onDelete: {
                                        panelToDelete = account
                                        showDeleteConfirmation = true
                                    }
                                )
                            }
                        }
                        .padding()
                        .padding(.bottom, 80) // Room for FAB
                    }
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

// MARK: - Panel Card with Swipe Actions

struct PanelCard: View {
    let account: Account
    let isActive: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    
    private let deleteThreshold: CGFloat = -80
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            HStack {
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                }
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                )
            }
            .opacity(offset < -20 ? 1 : 0)
            
            // Main card
            Button(action: {
                if offset == 0 {
                    onSelect()
                } else {
                    withAnimation(.spring(response: 0.3)) {
                        offset = 0
                    }
                }
            }) {
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
                    
                    // Theme indicator
                    Circle()
                        .fill(LinearGradient(
                            colors: account.theme.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                    
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
                .frame(maxWidth: .infinity)
                .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isActive ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        if translation < 0 {
                            offset = max(translation, -100)
                        } else if offset < 0 {
                            offset = min(0, offset + translation)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.3)) {
                            if offset < deleteThreshold {
                                offset = -80
                            } else {
                                offset = 0
                            }
                        }
                    }
            )
        }
        .contentShape(Rectangle())
    }
}
