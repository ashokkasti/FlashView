import SwiftUI
import AppKit

@main
struct FlashViewApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    
    init() {
        // Enable macOS tabbed windows
        NSWindow.allowsAutomaticWindowTabbing = true
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
                    let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.5"
                    NSApplication.shared.orderFrontStandardAboutPanel(options: [
                        .credits: NSAttributedString(
                            string: "made with ❤️ in nepal",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 12),
                                .foregroundColor: NSColor.secondaryLabelColor
                            ]
                        ),
                        .applicationName: "FlashView" as NSString,
                        .version: version as NSString,
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
                    NSApp.keyWindow?.tabbingMode = .preferred
                    NSApp.sendAction(#selector(NSWindow.newWindowForTab(_:)), to: nil, from: nil)
                    DispatchQueue.main.async {
                        NSApp.sendAction(#selector(NSWindow.mergeAllWindows(_:)), to: nil, from: nil)
                    }
                }
                .keyboardShortcut("t", modifiers: .command)
                
                Button("Move Tab to New Window") {
                    NSApp.sendAction(#selector(NSWindow.moveTabToNewWindow(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
    }
}
