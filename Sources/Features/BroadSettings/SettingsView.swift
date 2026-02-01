import SwiftUI

struct SettingsView: View {
    @ObservedObject private var backgroundSettings = BackgroundSettings.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                LiquidBackgroundView()
                    .ignoresSafeArea()
                
                List {
                    // Background Selection
                    Section("Appearance") {
                        ForEach(BackgroundStyle.allCases) { style in
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    backgroundSettings.selectedBackground = style
                                }
                            } label: {
                                HStack {
                                    // Preview thumbnail
                                    Image(style.rawValue)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 35)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    
                                    Text(style.displayName)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    if backgroundSettings.selectedBackground == style {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
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
                        
                        HStack {
                            Text("Developer")
                            Spacer()
                            Text("XY Studios")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Section {
                        Link(destination: URL(string: "https://pterodactyl.io")!) {
                            HStack {
                                Text("Pterodactyl Panel")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Section {
                        Text("Manage panels in the Panels tab")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .background(Color.clear)
    }
}
