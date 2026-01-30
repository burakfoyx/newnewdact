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

// MARK: - Video Background with Fade-In and Fallback
struct LiquidBackgroundView: View {
    @ObservedObject private var accountManager = AccountManager.shared
    @State private var opacity: Double = 0
    @State private var isVideoReady: Bool = false
    
    private var nebulaColors: [Color] {
        accountManager.activeAccount?.theme.gradientColors ?? AppTheme.purple.gradientColors
    }
    
    var body: some View {
        ZStack {
            // Fallback nebula background (always present)
            FallbackNebulaBackground(colors: nebulaColors)
                .ignoresSafeArea()
            
            // Video background (overlays nebula when ready)
            VideoBackgroundView(videoName: "bg_loop", isVideoReady: $isVideoReady)
                .ignoresSafeArea()
                .opacity(isVideoReady ? opacity : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            // Fade in
            withAnimation(.easeOut(duration: 0.5)) {
                opacity = 1
            }
        }
        .onChange(of: isVideoReady) { _, ready in
            if ready {
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 1
                }
            }
        }
    }
}

// MARK: - Fallback Static Nebula (when video unavailable)
struct FallbackNebulaBackground: View {
    let colors: [Color]
    
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
            
            // Static nebula clouds
            GeometryReader { proxy in
                ZStack {
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [colors.first ?? .purple, (colors.first ?? .purple).opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 450, height: 300)
                        .blur(radius: 40)
                        .position(x: proxy.size.width * 0.25, y: proxy.size.height * 0.35)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [colors[safe: 1] ?? .indigo, (colors[safe: 1] ?? .indigo).opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 350, height: 350)
                        .blur(radius: 35)
                        .position(x: proxy.size.width * 0.75, y: proxy.size.height * 0.6)
                    
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [colors[safe: 2] ?? .blue, (colors[safe: 2] ?? .blue).opacity(0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 160
                            )
                        )
                        .frame(width: 300, height: 400)
                        .blur(radius: 35)
                        .position(x: proxy.size.width * 0.15, y: proxy.size.height * 0.7)
                }
            }
            .drawingGroup()
        }
    }
}

// Safe array access
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
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
