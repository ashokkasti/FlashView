import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var folderManager = FolderManager()
    @StateObject private var appState: AppState
    @State private var showRatingSettings = false
    
    init() {
        let manager = FolderManager()
        _folderManager = StateObject(wrappedValue: manager)
        _appState = StateObject(wrappedValue: AppState(folderManager: manager))
    }
    
    var body: some View {
        Group {
            if appState.currentFolder != nil {
                // We are in Viewer Mode
                ViewerWindowView()
                    .environmentObject(appState)
                    .environmentObject(folderManager)
                    .frame(minWidth: 800, minHeight: 600)
                    .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
                    .transition(.opacity)
            } else {
                // We are in Recent Folders Mode
                RecentFoldersView(folderManager: folderManager) { path in
                    appState.openFolder(path)
                }
                .padding(40)
                .frame(minWidth: 500, minHeight: 450)
                .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: appState.currentFolder)
        .background(WindowTabbingConfigurator())
        .onOpenURL { url in
            // Handle 'Open with FlashView'
            if url.isFileURL {
                appState.openFile(at: url)
            }
        }
        .sheet(isPresented: $showRatingSettings) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Done") { showRatingSettings = false }
                        .keyboardShortcut(.defaultAction)
                }
                .padding(12)
                RatingSettingsView()
            }
            .frame(width: 440)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showRatingSettings)) { _ in
            showRatingSettings = true
        }
    }
}

private struct WindowTabbingConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.tabbingMode = .preferred
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.tabbingMode = .preferred
            }
        }
    }
}

extension Notification.Name {
    static let showRatingSettings = Notification.Name("showRatingSettings")
}
