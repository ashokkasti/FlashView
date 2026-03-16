import SwiftUI

extension Notification.Name {
    static let openNewFolder = Notification.Name("openNewFolder")
}

@main
struct FlashViewApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    
    init() {
        // Enable macOS tabbed windows
        NSWindow.allowsAutomaticTabbing = true
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .applyTheme()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
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
                        .version: "0.0.5" as NSString,
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
            
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .openNewFolder, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
                
                Button("Move Tab to New Window") {
                    NSApp.keyWindow?.moveTab(to: nil, index: 0)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
    }
}
