import SwiftUI
import UIKit

// MARK: - iOS 26 Native Liquid Glass

// MARK: - LiquidGlassCard

public struct LiquidGlassCard<Content: View>: View {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding()
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - LiquidButtonStyle

public struct LiquidButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(.clear))
            .glassEffect(.clear.interactive(), in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

public enum GlassVariant {
    case clear
    case frosted
    case heavy
}

extension ButtonStyle where Self == LiquidButtonStyle {
    public static var liquidGlass: LiquidButtonStyle { LiquidButtonStyle() }
}

// MARK: - Legacy Glass Modifier (kept for LiquidGlassDock usage)

extension View {
    public func liquidGlass(variant: GlassVariant = .clear, cornerRadius: CGFloat = 24) -> some View {
        self.glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

public struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    public init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    public var body: some View {
        content
    }
}

public struct GlassEffectTransition {}
