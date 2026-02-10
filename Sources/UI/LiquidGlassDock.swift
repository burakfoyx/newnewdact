import SwiftUI

/// A shared container that replicates the exact visual style of the MainTabBar.
/// It applies the Liquid Glass effect, shadows, and padding.
public struct LiquidGlassDock<Content: View>: View {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            content
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        // Exact modifiers from MainTabBar.swift
        .liquidGlass(variant: .heavy, cornerRadius: 100)
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}

/// A shared button component that replicates the exact visual style of MainTabBarButton.
public struct LiquidDockButton: View {
    let title: String
    let icon: String // System image name
    let isSelected: Bool
    let namespace: Namespace.ID
    let matchId: String // ID for matchedGeometryEffect
    let action: () -> Void
    
    public init(
        title: String,
        icon: String,
        isSelected: Bool,
        namespace: Namespace.ID,
        matchId: String = "TabBackground",
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.namespace = namespace
        self.matchId = matchId
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .symbolEffect(.bounce, value: isSelected)
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            // Selected: Blue, Unselected: White (Matching MainTabBar)
            .foregroundStyle(isSelected ? Color.blue : .white)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .matchedGeometryEffect(id: matchId, in: namespace)
                }
            }
        }
    }
}
