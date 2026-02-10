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
        LiquidGlassDock {
            ForEach(tabs) { tab in
                LiquidDockButton(
                    title: tab.title,
                    icon: tab.icon,
                    isSelected: selectedTab == tab.index,
                    namespace: animation
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab.index
                    }
                }
            }
        }
    }
}

struct MainTabItem: Identifiable {
    let index: Int
    let title: String
    let icon: String
    var id: Int { index }
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
