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
    @Namespace private var animation // Add namespace for matched geometry
    @Environment(\.dismiss) private var dismiss
    
    // Initializer to match expected format
    init(server: ServerAttributes, serverName: String? = nil, statusState: String? = nil, stats: WebsocketResponse.Stats? = nil, limits: ServerLimits? = nil) {
        self.server = server
        self.serverName = serverName ?? server.name
        self.statusState = statusState ?? "unknown"
        self.stats = stats
        self.limits = limits ?? server.limits
    }
    
    // Main tabs to show directly
    private let mainTabs: [ServerTab] = [.console, .analytics, .backups, .alerts]
    
    // Tabs to show in "More" menu
    private let moreTabs: [ServerTab] = [
        .files, .network, .startup, .schedules,
        .databases, .users, .settings
    ]

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
                }
                .padding(.horizontal)
                .padding(.top, 8) // Adjust for safe area
                
                Spacer()
                
                // Floating Tab Bar
                LiquidGlassDock {
                    // Main Tabs
                    ForEach(mainTabs) { tab in
                        LiquidDockButton(
                            title: tab.rawValue,
                            icon: tab.icon,
                            isSelected: selectedTab == tab,
                            namespace: animation
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        }
                    }
                    
                    // "More" Tab Menu
                    Menu {
                        ForEach(moreTabs) { tab in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTab = tab
                                }
                            } label: {
                                Label(tab.rawValue, systemImage: tab.icon)
                            }
                        }
                    } label: {
                        // Reuse LiquidDockButton visual manually for the menu trigger
                        // since LiquidDockButton is a Button which might conflict with Menu label
                        // We will use a custom view that matches LiquidDockButton visual perfectly
                        VStack(spacing: 4) {
                            Image(systemName: isMoreTabSelected ? selectedTab.icon : "ellipsis.circle")
                                .font(.system(size: 20, weight: isMoreTabSelected ? .semibold : .regular))
                                .symbolEffect(.bounce, value: isMoreTabSelected)
                            
                            Text(isMoreTabSelected ? selectedTab.rawValue : "More")
                                .font(.system(size: 10, weight: isMoreTabSelected ? .semibold : .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                        .foregroundStyle(isMoreTabSelected ? Color.blue : .white)
                        .background {
                            if isMoreTabSelected {
                                Capsule()
                                    .fill(Color.white.opacity(0.1))
                                    .matchedGeometryEffect(id: "TabBackground", in: animation)
                            }
                        }
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }

    private var isMoreTabSelected: Bool {
        moreTabs.contains(selectedTab)
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
