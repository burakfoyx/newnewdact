import SwiftUI

struct SettingsView: View {
    @ObservedObject var accountManager = AccountManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                List {
                    Section("Nebula Theme") {
                        if let active = accountManager.activeAccount {
                            ForEach(AppTheme.allCases) { theme in
                                Button {
                                    var updated = active
                                    updated.theme = theme
                                    accountManager.updateAccount(updated)
                                } label: {
                                    HStack {
                                        // Color preview circles
                                        HStack(spacing: -8) {
                                            ForEach(0..<min(3, theme.gradientColors.count), id: \.self) { i in
                                                Circle()
                                                    .fill(theme.gradientColors[i])
                                                    .frame(width: 24, height: 24)
                                                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                                            }
                                        }
                                        
                                        Text(theme.rawValue)
                                            .foregroundStyle(.white)
                                        
                                        Spacer()
                                        
                                        if active.theme == theme {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        }
                                    }
                                }
                            }
                        } else {
                            Text("Select a panel first")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Section("About") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.1.0")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Text("Build")
                            Spacer()
                            Text("iOS 26")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Section {
                        Text("Manage panels in the Panels tab")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
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
