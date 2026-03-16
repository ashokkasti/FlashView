import SwiftUI

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
        case .eyeFriendly: return .dark
        }
    }
    
    var accent: Color {
        switch self {
        case .system: return .accentColor
        case .dark: return .blue
        case .light: return .blue
        case .eyeFriendly: return Color(red: 0.85, green: 0.65, blue: 0.13) // warm amber
        }
    }
    
    var background: Color {
        switch self {
        case .system: return Color(nsColor: .underPageBackgroundColor)
        case .dark: return Color(red: 0.11, green: 0.11, blue: 0.12)
        case .light: return Color(red: 0.96, green: 0.96, blue: 0.96)
        case .eyeFriendly: return Color(red: 0.15, green: 0.13, blue: 0.10) // warm dark brown
        }
    }
    
    var sidebarBackground: Color {
        switch self {
        case .system: return Color(nsColor: .headerTextColor).opacity(0.05)
        case .dark: return Color(red: 0.14, green: 0.14, blue: 0.16)
        case .light: return Color(red: 0.93, green: 0.93, blue: 0.93)
        case .eyeFriendly: return Color(red: 0.18, green: 0.16, blue: 0.12)
        }
    }
    
    var textPrimary: Color {
        switch self {
        case .system: return .primary
        case .dark: return .white
        case .light: return .black
        case .eyeFriendly: return Color(red: 0.95, green: 0.92, blue: 0.85)
        }
    }
    
    var textSecondary: Color {
        switch self {
        case .system: return .secondary
        case .dark: return .gray
        case .light: return .gray
        case .eyeFriendly: return Color(red: 0.72, green: 0.68, blue: 0.58)
        }
    }
}

class ThemeManager: ObservableObject {
    @AppStorage("appTheme") var selectedTheme: AppTheme = .system
    
    static let shared = ThemeManager()
    
    var theme: AppTheme { selectedTheme }
}
