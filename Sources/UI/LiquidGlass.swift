import SwiftUI

// MARK: - iOS 26 Native Liquid Glass
// Using the native SwiftUI glassEffect API introduced in iOS 26

// MARK: - View Extension for Native Glass Effect

extension View {
    /// Apply native iOS 26 Liquid Glass effect with .clear variant (most transparent, edge bending)
    @ViewBuilder
    public func liquidGlassEffect(in shape: some Shape = RoundedRectangle(cornerRadius: 20, style: .continuous)) -> some View {
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
    public func liquidGlass(variant: GlassVariant = .clear, cornerRadius: CGFloat = 24) -> some View {
        self.glassEffect(.clear, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

public enum GlassVariant {
    case clear
    case frosted
    case heavy
}

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

// MARK: - GlassEffectContainer

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

extension ButtonStyle where Self == LiquidButtonStyle {
    public static var glass: LiquidButtonStyle { LiquidButtonStyle() }
}

// MARK: - Background Style Enum

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case darkBlueBlurred = "dark blue blurred"
    case darkBlueNoBlur = "dark blue  no blur"
    case nebulaBlurred = "nebula blurred"
    case nebulaNoBlur = "nebula no blur"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .darkBlueBlurred: return "Dark Blue (Blurred)"
        case .darkBlueNoBlur: return "Dark Blue"
        case .nebulaBlurred: return "Nebula (Blurred)"
        case .nebulaNoBlur: return "Nebula"
        }
    }
}

// MARK: - Background Settings Manager

class BackgroundSettings: ObservableObject {
    static let shared = BackgroundSettings()
    
    @Published var selectedBackground: BackgroundStyle {
        didSet {
            UserDefaults.standard.set(selectedBackground.rawValue, forKey: "selectedBackground")
        }
    }
    
    private init() {
        if let stored = UserDefaults.standard.string(forKey: "selectedBackground"),
           let style = BackgroundStyle(rawValue: stored) {
            selectedBackground = style
        } else {
            selectedBackground = .darkBlueBlurred
        }
    }
}

// MARK: - App Background View

struct AppBackgroundView: View {
    @ObservedObject private var settings = BackgroundSettings.shared
    
    var body: some View {
        Image(settings.selectedBackground.rawValue)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .ignoresSafeArea()
    }
}

// MARK: - Legacy Compatibility
typealias LiquidBackgroundView = AppBackgroundView
