import SwiftUI

struct MainTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var animation
    
    // Main Tabs matching ContentView
    // 0: Panels (rectangle.stack.fill)
    // 1: API (key.fill)
    // 2: Servers (server.rack)
    // 3: Settings (gearshape.fill)
    
    private let tabs: [MainTabItem] = [
        MainTabItem(index: 0, title: "Panels", icon: "rectangle.stack.fill"),
        MainTabItem(index: 1, title: "API", icon: "key.fill"),
        MainTabItem(index: 2, title: "Servers", icon: "server.rack"),
        MainTabItem(index: 3, title: "Settings", icon: "gearshape.fill")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs) { tab in
                MainTabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab.index,
                    namespace: animation,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab.index
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        // Use the exact same Heavy Glass + Clear Material style as ServerDetailTabBar
        .liquidGlass(variant: .heavy, cornerRadius: 100)
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}

struct MainTabItem: Identifiable {
    let index: Int
    let title: String
    let icon: String
    var id: Int { index }
}

private struct MainTabBarButton: View {
    let tab: MainTabItem
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .symbolEffect(.bounce, value: isSelected)
                
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            // Selected: Blue, Unselected: White (Matching Screenshot)
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
        VStack {
            Spacer()
            MainTabBar(selectedTab: .constant(0))
        }
    }
}
