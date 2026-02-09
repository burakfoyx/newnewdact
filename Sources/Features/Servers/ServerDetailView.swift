//
//  ServerDetailView.swift
//  XYIdactyl
//
//  Created by Burak on 10.02.2026.
//

import SwiftUI

struct ServerDetailView: View {
    let server: ServerAttributes
    let serverName: String
    let statusState: String
    var stats: WebsocketResponse.Stats?
    var limits: ServerLimits?
    
    @State private var selectedTab: ServerTab = .console
    @Environment(\.dismiss) private var dismiss
    
    // Initializer to match expected format
    init(server: ServerAttributes, serverName: String? = nil, statusState: String? = nil, stats: WebsocketResponse.Stats? = nil, limits: ServerLimits? = nil) {
        self.server = server
        self.serverName = serverName ?? server.name
        self.statusState = statusState ?? "unknown"
        self.stats = stats
        self.limits = limits ?? server.limits
    }
    
    var body: some View {
        ZStack {
            // 1. Background Layer
            // Use a gradient or image as the base liquid glass background
            // Assuming "Background" color set exists, else fallback to dark gray
            Color("Background").opacity(0.8) // Reduced opacity to let app background show if any
                .ignoresSafeArea()
            
            // Optional: Background Blob/Gradient for depth
            GeometryReader { proxy in
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .position(x: proxy.size.width * 0.8, y: proxy.size.height * 0.2)
                    .blur(radius: 60)
                
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 250, height: 250)
                    .position(x: proxy.size.width * 0.2, y: proxy.size.height * 0.6)
                    .blur(radius: 50)
            }
            .ignoresSafeArea()
            
            // 2. Content Layer
            // Switch based on tab
            switch selectedTab {
            case .console:
                // ConsoleView requires ConsoleViewModel. We might need to construct it or
                // ensure ConsoleView can handle it.
                // Assuming ConsoleView init(server: ...) or similar based on previous file read.
                // Re-reading ConsoleView init: init(viewModel: ConsoleViewModel, limits: ServerLimits?, serverName: String)
                // We need to create specific view models if they aren't passed in.
                // For simplicity here, we assume we can create them or adapt.
                // Wait, ConsoleView.swift INIT was `init(serverId: String, limits: ServerLimits? = nil)` in ViewModel but View took `viewModel`.
                // I will create the ViewModel inline here or pass it.
                // Creating StateObject inside body is bad. We should wrapping content in a view that owns the state.
                // Simple approach: Use lazy views via function construction or specialized wrappers.
                ConsoleViewWrapper(server: server, limits: limits)
            case .analytics:
                HistoryView(server: server, serverName: serverName, statusState: statusState, stats: stats, limits: limits)
            case .backups:
                BackupView(server: server, serverName: serverName, statusState: statusState, stats: stats, limits: limits)
            case .alerts:
                AlertsListView(server: server, serverName: serverName, statusState: statusState, stats: stats, limits: limits)
            case .files:
                FileManagerView(server: server, serverName: serverName, statusState: statusState, stats: stats, limits: limits)
            case .network:
                NetworkView(server: server, serverName: serverName, statusState: statusState, stats: stats, limits: limits)
            case .startup:
                StartupView(server: server, serverName: serverName, statusState: statusState, stats: stats, limits: limits)
            case .schedules:
                SchedulesView(serverId: server.identifier, serverName: serverName, statusState: statusState, stats: stats, limits: limits)
            case .databases:
                DatabasesView(serverId: server.identifier, serverName: serverName, statusState: statusState, stats: stats, limits: limits)
            case .users:
                UsersView(serverId: server.identifier, serverName: serverName, statusState: statusState, stats: stats, limits: limits)
            case .settings:
                ServerSettingsView(server: server, serverName: serverName, statusState: statusState, stats: stats, limits: limits)
            }
            
            // 3. UI Overlay Layer (Header + TabBar)
            VStack {
                // Header Area
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Text(serverName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    // Optional right side actions (e.g. power)
                    // Could add power button here
                }
                .padding(.horizontal)
                .padding(.top, 8) // Adjust for safe area
                
                Spacer()
                
                // Floating Tab Bar
                ServerDetailTabBar(selectedTab: $selectedTab)
            }
        }
        .navigationBarHidden(true)
    }
}

// Wrapper for ConsoleView to handle StateObject instantiation correctly
struct ConsoleViewWrapper: View {
    let server: ServerAttributes
    let limits: ServerLimits?
    
    @StateObject private var viewModel: ConsoleViewModel
    
    init(server: ServerAttributes, limits: ServerLimits?) {
        self.server = server
        self.limits = limits
        // Initialize StateObject
        _viewModel = StateObject(wrappedValue: ConsoleViewModel(serverId: server.identifier, limits: limits))
    }
    
    var body: some View {
        ConsoleView(viewModel: viewModel, limits: limits, serverName: server.name)
    }
}
