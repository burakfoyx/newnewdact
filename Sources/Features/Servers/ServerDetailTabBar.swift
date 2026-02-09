import SwiftUI

struct ServerDetailTabBar: View {
    @Binding var selectedTab: ServerTab
    
    // The main 4 tabs + "More"
    private let mainTabs: [ServerTab] = [.console, .analytics, .backups, .alerts]
    
    // The rest of the tabs for the "More" menu
    private let moreTabs: [ServerTab] = [
        .files, .network, .startup, .schedules, .databases, .users, .settings
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            // Main Tabs
            ForEach(mainTabs) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
            }
            
            // More Tab
            Menu {
                ForEach(moreTabs) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.icon)
                    }
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("More")
                        .font(.system(size: 10, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(isMoreTabSelected ? .white : .white.opacity(0.5))
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 4)
        .background {
            Capsule()
                .fill(.ultraThinMaterial.opacity(0.1)) // Subtle base
                .liquidGlassEffect(in: Capsule()) // Native Liquid Glass
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var isMoreTabSelected: Bool {
        moreTabs.contains(selectedTab)
    }
}

private struct TabBarButton: View {
    let tab: ServerTab
    let isSelected: Bool
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
            .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
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
