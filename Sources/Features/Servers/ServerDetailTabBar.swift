import SwiftUI

struct ServerDetailTabBar: View {
    @Binding var selectedTab: ServerTab
    @Namespace private var animation // For smooth selection transition
    
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
                    namespace: animation,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                )
            }
            
            // More Tab
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
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("More")
                        .font(.system(size: 10, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                // Selection logic for "More"
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
        .padding(.horizontal, 6)
        .padding(.vertical, 6)

        .liquidGlass(variant: .heavy, cornerRadius: 100)
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 24)
        .padding(.bottom, 20) // Floating higher as per typical iOS spacing
    }
    
    private var isMoreTabSelected: Bool {
        moreTabs.contains(selectedTab)
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
            // Selected: Blue, Unselected: White
            .foregroundStyle(isSelected ? Color.blue : .white)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .matchedGeometryEffect(id: "TabBackground", in: namespace)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        // Mock background content
        VStack {
            ForEach(0..<10) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(.gray.opacity(0.2))
                    .frame(height: 60)
                    .padding(.horizontal)
            }
        }
        
        VStack {
            Spacer()
            ServerDetailTabBar(selectedTab: .constant(.console))
        }
    }
}
