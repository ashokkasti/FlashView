import SwiftUI

@main
struct FlashViewApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .applyTheme()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About FlashView") {
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .credits: NSAttributedString(
                            string: "made with ❤️ in nepal",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 12),
                                .foregroundColor: NSColor.secondaryLabelColor
                            ]
                        ),
                        .applicationName: "FlashView" as NSString,
                        .version: "0.0.4" as NSString,
                    ])
                }
            }
            
            CommandMenu("Theme") {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        themeManager.selectedTheme = theme
                    } label: {
                        HStack {
                            Text(theme.rawValue)
                            if themeManager.selectedTheme == theme {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        }
    }
}
