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

// MARK: - Video Background with Fade-In
struct LiquidBackgroundView: View {
    @State private var opacity: Double = 0
    @State private var isVideoReady: Bool = false
    
    var body: some View {
        ZStack {
            // Fallback nebula background (always present)
            StaticNebulaBackground()
                .ignoresSafeArea()
            
            // Video background (overlays nebula when ready)
            VideoBackgroundView(videoName: "bg_loop", isVideoReady: $isVideoReady)
                .ignoresSafeArea()
                .opacity(isVideoReady ? opacity : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(Color.black) // Ensure black base
        .onAppear {
            // Check if global player is already running to avoid fade-in flicker
            if VideoPlayerManager.shared.player.currentItem?.status == .readyToPlay {
                isVideoReady = true
                opacity = 1
            } else {
                // First load fade-in
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 1
                }
            }
        }
        .onChange(of: isVideoReady) { _, ready in
             // Ensure opacity works if it wasn't ready initially but became ready
            if ready && opacity < 1 {
                 withAnimation(.easeOut(duration: 0.3)) {
                     opacity = 1
                 }
            }
        }
    }
}

// MARK: - Static Nebula Background (fallback when video unavailable)
struct StaticNebulaBackground: View {
    var body: some View {
        ZStack {
            // Deep Space Base - Brightened slightly for visibility debugging
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.15, green: 0.08, blue: 0.25),
                    Color(red: 0.08, green: 0.10, blue: 0.30)
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
                                colors: [Color.purple.opacity(0.5), Color.purple.opacity(0)],
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
                                colors: [Color.indigo.opacity(0.4), Color.indigo.opacity(0)],
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
                                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0)],
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
