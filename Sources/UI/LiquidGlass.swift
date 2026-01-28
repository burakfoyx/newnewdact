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
            // Reduced shadow opacity to avoid "black box" look, per user request
            .shadow(color: config.tintColor?.opacity(0.1) ?? .black.opacity(0.05), radius: 8, x: 0, y: 4)
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

// MARK: - Animated Nebula Background
struct LiquidBackgroundView: View {
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var animate = false
    
    private var nebulaColors: [Color] {
        accountManager.activeAccount?.theme.gradientColors ?? AppTheme.purple.gradientColors
    }
    
    var body: some View {
        ZStack {
            // Deep Space Base
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.08, green: 0.04, blue: 0.15),
                    Color(red: 0.04, green: 0.06, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Stars Layer
            StarsView(animate: animate)
            
            // Nebula Clouds Layer
            NebulaClouds(colors: nebulaColors, animate: animate)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: 0.5)) {
                animate = true
            }
        }
    }
}

// MARK: - Bloomy Moving Stars (CPU Optimized)
struct StarsView: View {
    let animate: Bool
    
    // Reduced star count for better performance
    private static let starData: [(x: CGFloat, y: CGFloat, size: CGFloat)] = (0..<30).map { _ in
        (
            CGFloat.random(in: 0...1),
            CGFloat.random(in: 0...1),
            CGFloat.random(in: 1.5...3)
        )
    }
    
    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                // Use Canvas for efficient batch rendering
                for star in Self.starData {
                    let position = CGPoint(x: star.x * size.width, y: star.y * size.height)
                    
                    // Draw bloom (simple circle with opacity)
                    let bloomRect = CGRect(
                        x: position.x - star.size * 3,
                        y: position.y - star.size * 3,
                        width: star.size * 6,
                        height: star.size * 6
                    )
                    context.fill(
                        Circle().path(in: bloomRect),
                        with: .color(.white.opacity(0.15))
                    )
                    
                    // Draw star core
                    let starRect = CGRect(
                        x: position.x - star.size / 2,
                        y: position.y - star.size / 2,
                        width: star.size,
                        height: star.size
                    )
                    context.fill(
                        Circle().path(in: starRect),
                        with: .color(.white.opacity(0.9))
                    )
                }
            }
        }
        .opacity(0.85)
        // Very slow rotation for subtle star field movement (10 minutes per rotation)
        .rotationEffect(Angle(degrees: animate ? 360 : 0))
        .animation(animate ? .linear(duration: 600).repeatForever(autoreverses: false) : nil, value: animate)
    }
}

// MARK: - Nebula Clouds (CPU Optimized)
struct NebulaClouds: View {
    let colors: [Color]
    let animate: Bool
    
    private var palette: [Color] {
        var base = colors
        if base.count < 3 {
            base.append(contentsOf: [.indigo.opacity(0.4), .purple.opacity(0.3)])
        }
        return base
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Cloud 1 - Large Ellipse (reduced blur, slower animation)
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [palette[0], palette[0].opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 450, height: 300)
                    .blur(radius: 40)
                    .position(x: proxy.size.width * 0.25, y: proxy.size.height * 0.35)
                    .offset(x: animate ? -20 : 20, y: animate ? -15 : 15)
                    .animation(animate ? .easeInOut(duration: 45).repeatForever(autoreverses: true) : nil, value: animate)
                
                // Cloud 2 - Circle (reduced blur, slower animation)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette[1 % palette.count], palette[1 % palette.count].opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .frame(width: 350, height: 350)
                    .blur(radius: 35)
                    .position(x: proxy.size.width * 0.75, y: proxy.size.height * 0.6)
                    .offset(x: animate ? 25 : -25, y: animate ? 20 : -20)
                    .animation(animate ? .easeInOut(duration: 55).repeatForever(autoreverses: true) : nil, value: animate)
                
                // Cloud 3 - Accent (reduced blur, slower animation)
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [palette[2 % palette.count], palette[2 % palette.count].opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 160
                        )
                    )
                    .frame(width: 300, height: 400)
                    .blur(radius: 35)
                    .position(x: proxy.size.width * 0.15, y: proxy.size.height * 0.7)
                    .offset(x: animate ? 15 : -10, y: animate ? -25 : 15)
                    .animation(animate ? .easeInOut(duration: 60).repeatForever(autoreverses: true) : nil, value: animate)
            }
        }
        .drawingGroup() // Flatten to single layer for GPU efficiency
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
