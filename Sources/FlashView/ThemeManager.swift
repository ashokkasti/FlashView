import SwiftUI
import AppKit

enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"
    case eyeFriendly = "Eye Friendly"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        case .eyeFriendly: return .light
        }
    }
    
    /// Window-level tint — this is what actually makes eye-friendly look pink
    var windowTint: Color? {
        switch self {
        case .eyeFriendly: return Color(red: 1.0, green: 0.82, blue: 0.90)
        default: return nil
        }
    }

    /// Foreground overlay tint so eye-friendly is clearly distinguishable from plain light mode.
    var overlayTint: Color? {
        switch self {
        case .eyeFriendly: return Color(red: 1.0, green: 0.80, blue: 0.89)
        default: return nil
        }
    }
}

class ThemeManager: ObservableObject {
    @AppStorage("appTheme") var selectedTheme: AppTheme = .system
    
    static let shared = ThemeManager()
    
    var theme: AppTheme { selectedTheme }
}

// MARK: - Window Tint Modifier (applies pink tint to entire window)
struct WindowTintModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(themeManager.theme.colorScheme)
            .background(
                WindowTintView(tint: themeManager.theme.windowTint)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            )
            .overlay {
                if let overlayTint = themeManager.theme.overlayTint {
                    overlayTint
                        .opacity(0.20)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
    }
}

/// Uses NSVisualEffectView with a colored tint to shift the entire window appearance
struct WindowTintView: NSViewRepresentable {
    let tint: Color?
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .underWindowBackground
        updateTint(view)
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        updateTint(nsView)
    }
    
    private func updateTint(_ view: NSVisualEffectView) {
        view.wantsLayer = true
        if let tint = tint {
            let nsColor = NSColor(tint).withAlphaComponent(0.36)
            view.material = .underWindowBackground
            view.layer?.backgroundColor = nsColor.cgColor
        } else {
            view.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}

extension View {
    func applyTheme() -> some View {
        modifier(WindowTintModifier())
    }
}
