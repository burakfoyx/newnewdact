import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
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
            .navigationTitle("Settings")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .background(Color.clear)
    }
}
