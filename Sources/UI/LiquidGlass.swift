import SwiftUI

//
//  LiquidGlass.swift
//  XYIdactyl
//
//  Created for iOS 26 Liquid Glass Design System.
//

/// A container that applies the Liquid Glass aesthetic:
/// - Translucent background with heavy blur (Refraction)
/// - Specular highlights (simulated with gradients)
/// - Depth effects (shadows and scaling)
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            // The core "Liquid" material
            .background(.regularMaterial) 
            // Add a subtle specular highlight gradient overlay
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.1), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            // Depth shadow - diffuse and soft
            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
    }
}

extension View {
    /// Applies a liquid glass background to the view.
    func liquidGlassBackground() -> some View {
        self
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(.white.opacity(0.05))
                    .blendMode(.overlay)
            )
    }
}

/// A button style that mimics the tactile "press" of a glass surface.
struct LiquidButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(
                Capsule()
                    .fill(.thickMaterial)
                    .shadow(color: .white.opacity(0.1), radius: 1, x: -1, y: -1) // Inner light
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)   // Drop shadow
            )
            .overlay(
                Capsule()
                    .stroke(LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
