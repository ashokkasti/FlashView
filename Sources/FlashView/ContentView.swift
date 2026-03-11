import SwiftUI

struct ContentView: View {
    @StateObject private var folderManager = FolderManager()
    @StateObject private var appState: AppState
    
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
        .onOpenURL { url in
            // Handle 'Open with FlashView'
            if url.isFileURL {
                appState.openFile(at: url)
            }
        }
    }
}
