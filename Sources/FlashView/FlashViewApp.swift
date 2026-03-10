import SwiftUI

@main
struct FlashViewApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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
                        .version: "1.0" as NSString,
                    ])
                }
            }
        }
    }
}
