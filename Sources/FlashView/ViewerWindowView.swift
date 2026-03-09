import SwiftUI

struct ViewerWindowView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HSplitView {
            // Left Sidebar
            if appState.isSidebarVisible {
                SidebarView()
                    .frame(minWidth: 150, idealWidth: 200, maxWidth: 300)
            }
            
            // Main Content Area
            VStack(spacing: 0) {
                MinimalToolbar()
                
                if appState.viewImages.isEmpty {
                    EmptyStateView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            MainPreviewView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black)
                            
                            // Fullscreen mode hides thumbnails after fade, but MVP can just hide them via a simple bool check
                            if !appState.isFullscreen {
                                ThumbnailStripView()
                                    .frame(height: 140) // 120-160px as per spec
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 400)
            
            // Right Editing Panel
            if appState.isInspectorVisible {
                EditingPanelView()
                    .frame(minWidth: 200, idealWidth: 250, maxWidth: 350)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        // Keyboard Shortcuts
        .background(
            Group {
                Button("") { appState.previousImage() }.keyboardShortcut(.leftArrow, modifiers: [])
                Button("") { appState.nextImage() }.keyboardShortcut(.rightArrow, modifiers: [])
                Button("") { appState.isSlideshowActive.toggle() }.keyboardShortcut(.space, modifiers: [])
                Button("") { appState.deleteCurrentImage() }.keyboardShortcut("d", modifiers: [])
                
                // Ratings 1=Bad, 2=Maybe, 3=Good
                Button("") { appState.applyRating(1) }.keyboardShortcut("1", modifiers: [])
                Button("") { appState.applyRating(2) }.keyboardShortcut("2", modifiers: [])
                Button("") { appState.applyRating(3) }.keyboardShortcut("3", modifiers: [])
            }
            .opacity(0)
        )
        // Slideshow Timer
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            if appState.isSlideshowActive {
                appState.nextImage()
            }
        }
    }
}

// Minimal Toolbar replacement to support toggling sidebars
struct MinimalToolbar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            Button(action: {
                withAnimation { appState.isSidebarVisible.toggle() }
            }) {
                Image(systemName: "sidebar.left")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal)
            
            Spacer()
            
            if let folder = appState.currentFolder {
                Text((folder as NSString).lastPathComponent)
                    .font(.headline)
            }
            if let filter = appState.selectedRatingFilter {
                Text("(\(filter) Stars)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation { appState.isInspectorVisible.toggle() }
            }) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(appState.isInspectorVisible ? .accentColor : .primary)
            }
            .buttonStyle(.borderless)
            .padding(.horizontal)
            
            Button(action: {
                appState.isFullscreen.toggle()
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderless)
            .padding(.trailing)
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }
}


struct EmptyStateView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            if appState.selectedRatingFilter != nil {
                Text("No images found in this bucket")
                    .font(.title2)
                    .foregroundColor(.secondary)
            } else {
                Text("No images found in this folder")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            Button("Choose another folder") {
                appState.closeFolder()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
