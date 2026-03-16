import SwiftUI

struct ThemeModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(themeManager.theme.colorScheme)
            .environment(\._themeAccent, themeManager.theme.accent)
    }
}

extension View {
    func applyTheme() -> some View {
        modifier(ThemeModifier())
    }
}

// Environment key for accent override
private struct ThemeAccentKey: EnvironmentKey {
    static let defaultValue: Color = .accentColor
}

extension EnvironmentValues {
    var _themeAccent: Color {
        get { self[ThemeAccentKey.self] }
        set { self[ThemeAccentKey.self] = newValue }
    }
}

struct ThemeBackgroundModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared
    
    func body(content: Content) -> some View {
        content
            .background(themeManager.theme.background)
            .foregroundColor(themeManager.theme.textPrimary)
    }
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemeBackgroundModifier())
    }
}
