//
//  ServerDetailTabBar.swift
//  XYIdactyl
//
//  Created by Burak on 10.02.2026.
//

import SwiftUI

enum ServerTab: String, CaseIterable, Identifiable {
    case console = "Console"
    case analytics = "Analytics"
    case backups = "Backups"
    case alerts = "Alerts"
    case files = "Files"
    case network = "Network"
    case startup = "Startup"
    case schedules = "Schedules"
    case databases = "Databases"
    case users = "Users"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .console: return "terminal.fill"
        case .analytics: return "chart.xyaxis.line"
        case .backups: return "archivebox.fill"
        case .alerts: return "bell.fill"
        case .files: return "folder.fill"
        case .network: return "network"
        case .startup: return "play.circle.fill"
        case .schedules: return "clock.fill"
        case .databases: return "cylinder.fill"
        case .users: return "person.2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct ServerDetailTabBar: View {
    @Binding var selectedTab: ServerTab
    @Namespace private var animation
    
    // Main tabs to show directly
    private let mainTabs: [ServerTab] = [.console, .analytics, .backups, .alerts]
    
    // Tabs to show in "More" menu
    private let moreTabs: [ServerTab] = [
        .files, .network, .startup, .schedules,
        .databases, .users, .settings
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            // Main Tabs
            ForEach(mainTabs) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
            
            // "More" Tab
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
                VStack(spacing: 4) {
                    Image(systemName: isMoreTabSelected ? moreTabIcon : "ellipsis.circle")
                        .font(.system(size: 20, weight: isMoreTabSelected ? .semibold : .regular))
                        .symbolEffect(.bounce, value: isMoreTabSelected)
                    
                    Text(isMoreTabSelected ? selectedTab.rawValue : "More")
                        .font(.system(size: 10, weight: isMoreTabSelected ? .semibold : .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .foregroundStyle(isMoreTabSelected ? .white : .white.opacity(0.6))
                .background {
                    if isMoreTabSelected {
                        Capsule()
                            .fill(.white.opacity(0.2))
                            .matchedGeometryEffect(id: "TabBackground", in: animation)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 16)
        .padding(.bottom, 8) // Lift slightly from bottom
    }
    
    private var isMoreTabSelected: Bool {
        moreTabs.contains(selectedTab)
    }
    
    private var moreTabIcon: String {
        if isMoreTabSelected {
            return selectedTab.icon
        }
        return "ellipsis.circle"
    }
}

private struct TabBarButton: View {
    let tab: ServerTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .symbolEffect(.bounce, value: isSelected)
                
                Text(tab.rawValue)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
            .background {
                if isSelected {
                    Capsule()
                        .fill(.white.opacity(0.2))
                        .matchedGeometryEffect(id: "TabBackground", in: namespace)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            ServerDetailTabBar(selectedTab: .constant(.console))
        }
    }
}
