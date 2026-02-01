import SwiftUI

// MARK: - iOS 26 Native Liquid Glass
// Using the native SwiftUI glassEffect API introduced in iOS 26

// MARK: - View Extension for Native Glass Effect

extension View {
    /// Apply native iOS 26 Liquid Glass effect with .clear variant (most transparent, edge bending)
    @ViewBuilder
    public func liquidGlassEffect(in shape: some Shape = RoundedRectangle(cornerRadius: 20, style: .continuous)) -> some View {
        // Use the native iOS 26 glassEffect modifier with .clear variant
        self.glassEffect(.clear, in: shape)
    }
    
    /// Apply native iOS 26 Liquid Glass effect with regular variant
    @ViewBuilder
    public func liquidGlassRegular(in shape: some Shape = RoundedRectangle(cornerRadius: 20, style: .continuous)) -> some View {
        self.glassEffect(.regular, in: shape)
    }
}

// MARK: - Legacy liquidGlass modifier (now uses native API)

extension View {
    /// Legacy modifier that now uses native iOS 26 glassEffect
    /// All variants now use .clear for maximum transparency without tint
    public func liquidGlass(variant: GlassVariant = .clear, cornerRadius: CGFloat = 24) -> some View {
        // All variants use .clear for consistent transparent look without tint
        self.glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

public enum GlassVariant {
    case clear      // Very transparent - Apple's .clear with edge bending
    case frosted    // Balanced - Apple's .regular  
    case heavy      // Most opaque
}

// MARK: - LiquidGlassCard (uses native glass)

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

// MARK: - LiquidButtonStyle (uses native glass)

public struct LiquidButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(.clear)
            )
            .glassEffect(.clear.interactive(), in: Capsule())
            .contentShape(Capsule()) // Makes entire button area tappable
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

// MARK: - GlassEffectContainer

public struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    
    public init(spacing: CGFloat = 0, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    public var body: some View {
        // Just return content - the native glassEffect shapes will merge automatically
        content
    }
}

// MARK: - Other Types

public struct GlassEffectTransition {
    // Placeholder for native transition
}

extension ButtonStyle where Self == LiquidButtonStyle {
    public static var glass: LiquidButtonStyle { LiquidButtonStyle() }
}

// MARK: - App Background View (Static Image Based)
// Ready for 3-4 background images to be added

struct AppBackgroundView: View {
    // TODO: Add your background images to Assets.xcassets with names like:
    // - "bg_1", "bg_2", "bg_3", "bg_4"
    // Then uncomment and use the image name
    
    var body: some View {
        ZStack {
            // Placeholder gradient until images are added
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.10, green: 0.06, blue: 0.18),
                    Color(red: 0.06, green: 0.08, blue: 0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // When you add images, replace the gradient above with:
            // Image("bg_1")
            //     .resizable()
            //     .aspectRatio(contentMode: .fill)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Legacy Compatibility Alias
// This allows existing code to work without changes until you're ready to update references
typealias LiquidBackgroundView = AppBackgroundView
