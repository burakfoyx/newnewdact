import SwiftUI

// MARK: - Liquid Glass API Simulation
// Mimicking the "iOS 26" style API requested by the User.

// MARK: - Configuration Objects

public struct Glass {
    var variant: Material = .regular
    var tintColor: Color? = nil
    var isInteractive: Bool = false
    
    public static let regular = Glass(variant: .ultraThinMaterial)
    public static let thick = Glass(variant: .regularMaterial)
    public static let thin = Glass(variant: .thinMaterial)
    
    public func tint(_ color: Color) -> Glass {
        var copy = self
        copy.tintColor = color
        return copy
    }
    
    public func interactive(_ isActive: Bool = true) -> Glass {
        var copy = self
        copy.isInteractive = isActive
        return copy
    }
}

// MARK: - View Modifiers

extension View {
    public func glassEffect(_ config: Glass = .regular, in shape: some Shape = Capsule()) -> some View {
        self.modifier(LiquidGlassEffectModifier(config: config, shape: shape))
    }
    
    // Overload for default shape (Capsule) to match example .glassEffect()
    public func glassEffect() -> some View {
        self.modifier(LiquidGlassEffectModifier(config: .regular, shape: Capsule()))
    }
}

struct LiquidGlassEffectModifier<CShape: Shape>: ViewModifier {
    let config: Glass
    let shape: CShape
    
    func body(content: Content) -> some View {
        content
            .background(
                config.variant
            )
            .background(
                config.tintColor?.opacity(0.05) ?? Color.clear
            )
            .clipShape(shape)
            .overlay(
                // Glass bending / edge refraction imitation with stronger borders
                shape.stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.6),
                            .white.opacity(0.1),
                            .clear,
                            .white.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
            )
            // Inner light/reflection for depth
            .overlay(
                shape.stroke(Color.white.opacity(0.1), lineWidth: 1)
                     .padding(1)
                     .mask(shape)
            )
            .shadow(color: config.tintColor?.opacity(0.2) ?? .black.opacity(0.1), radius: 12, x: 0, y: 6)
            .scaleEffect(config.isInteractive ? 1.0 : 1.0)
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
        // In a real implementation this might use Canvas or similar for morphing.
        // For simulation, we just return the content, assuming the user arranges them.
        // The "morphing" visual effect is complex to sim without Metal/Canvas.
        // We will provide a wrapper that creates a unified glass look background if needed,
        // but the API example shows modifiers on children.
        content
    }
}

// MARK: - Other Types

public struct GlassEffectTransition {
    // Placeholder
}

public struct GlassButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .glassEffect(.regular.interactive())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassButtonStyle {
    public static var glass: GlassButtonStyle { GlassButtonStyle() }
}

extension Shape {
    // Helper to match .rect(cornerRadius:) syntax if using native or creating shim
    // SwiftUI already has .rect in newer versions, assuming user is on such version or we assume standard RoundedRectangle
    static func rect(cornerRadius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

// MARK: - Background View (Kept for compatibility)
struct LiquidBackgroundView: View {
    @State private var animate = false
    @ObservedObject var accountManager = AccountManager.shared
    
    var colors: [Color] {
        accountManager.activeAccount?.theme.gradientColors ?? AppTheme.blue.gradientColors
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Mesh Gradient Emulation
            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .fill(colors[0])
                        .frame(width: 400, height: 400)
                        .blur(radius: 80)
                        .offset(x: animate ? -100 : 100, y: animate ? -50 : 50)
                    
                    Circle()
                        .fill(colors[1])
                        .frame(width: 300, height: 300)
                        .blur(radius: 60)
                        .offset(x: animate ? 150 : -50, y: animate ? 200 : -100)
                    
                    if colors.count > 2 {
                        Circle()
                            .fill(colors[2])
                            .frame(width: 350, height: 350)
                            .blur(radius: 70)
                            .offset(x: animate ? -50 : 200, y: animate ? 300 : 100)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Legacy Compatibility (Restoring missing types)

public enum GlassVariant {
    case clear
    case frosted
    case heavy
    
    var material: Material {
        switch self {
        case .clear: return .ultraThinMaterial
        case .frosted: return .regularMaterial
        case .heavy: return .thickMaterial
        }
    }
}

extension View {
    // Restoring the old modifier signature used by other views
    public func liquidGlass(variant: GlassVariant = .frosted, cornerRadius: CGFloat = 24) -> some View {
        self.glassEffect(Glass(variant: variant.material), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

public struct LiquidGlassCard<Content: View>: View {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding()
            .liquidGlass(variant: .frosted, cornerRadius: 24)
    }
}

public struct LiquidButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .glassEffect(.regular.interactive())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: configuration.isPressed)
    }
}
