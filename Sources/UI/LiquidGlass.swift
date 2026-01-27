import SwiftUI

// MARK: - Liquid Glass Materials & Modifiers

enum GlassVariant {
    case clear
    case frosted
    case heavy
}

struct LiquidGlassModifier: ViewModifier {
    let variant: GlassVariant
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(materialForVariant(variant))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.6), location: 0),
                                .init(color: .white.opacity(0.1), location: 0.4),
                                .init(color: .clear, location: 0.5),
                                .init(color: .white.opacity(0.05), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
    }
    
    private func materialForVariant(_ variant: GlassVariant) -> Material {
        switch variant {
        case .clear: return .ultraThinMaterial
        case .frosted: return .regularMaterial
        case .heavy: return .thickMaterial
        }
    }
}

extension View {
    func liquidGlass(variant: GlassVariant = .frosted, cornerRadius: CGFloat = 24) -> some View {
        modifier(LiquidGlassModifier(variant: variant, cornerRadius: cornerRadius))
    }
}

// MARK: - Animated Background
struct LiquidBackgroundView: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Mesh Gradient Emulation using Blended Circles
            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.4))
                        .frame(width: 400, height: 400)
                        .blur(radius: 80)
                        .offset(x: animate ? -100 : 100, y: animate ? -50 : 50)
                    
                    Circle()
                        .fill(Color.purple.opacity(0.4))
                        .frame(width: 300, height: 300)
                        .blur(radius: 60)
                        .offset(x: animate ? 150 : -50, y: animate ? 200 : -100)
                    
                    Circle()
                        .fill(Color.cyan.opacity(0.3))
                        .frame(width: 350, height: 350)
                        .blur(radius: 70)
                        .offset(x: animate ? -50 : 200, y: animate ? 300 : 100)
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
