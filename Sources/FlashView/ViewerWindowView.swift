import SwiftUI

struct ViewerWindowView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            HSplitView {
                // Left Sidebar — narrower
                if appState.isSidebarVisible {
                    SidebarView()
                        .frame(minWidth: 120, idealWidth: 150, maxWidth: 250)
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
                                
                                if !appState.isFullscreen {
                                    ThumbnailStripView()
                                        .frame(height: 140)
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 400)
                
                // Right Editing Panel — no extra frame, EditingPanelView sets its own width
                if appState.isInspectorVisible {
                    EditingPanelView()
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
                    Button("") { appState.refreshFolder() }.keyboardShortcut("r", modifiers: [.command])
                    
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
            
            // MARK: - Processing Overlay (blocks interaction while processing)
            if appState.isProcessing {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Processing…")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .shadow(radius: 10)
            }
        }
    }
}

// Minimal Toolbar — file name, rating tag, refresh button
struct MinimalToolbar: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 6) {
            Button(action: {
                withAnimation { appState.isSidebarVisible.toggle() }
            }) {
                Image(systemName: "sidebar.left")
            }
            .buttonStyle(.borderless)
            .padding(.leading, 12)
            
            // Full folder path
            if let folder = appState.currentFolder {
                Text(folder)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            
            if let filter = appState.selectedRatingFilter {
                Text("(\(filter) Stars)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // File name in the center
            if let url = appState.currentImage {
                Text(url.lastPathComponent)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            // Rating tag
            if let r = appState.currentRating {
                Text(ratingLabel(r))
                    .font(.caption).bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ratingColor(r))
                    .cornerRadius(8)
                    .foregroundColor(r == 2 ? .black : .white)
            }
            
            // Image counter
            if !appState.viewImages.isEmpty {
                Text("\(appState.currentIndex + 1)/\(appState.viewImages.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            Spacer()
            
            // Refresh button
            Button(action: {
                appState.refreshFolder()
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh folder (⌘R)")
            
            Button(action: {
                appState.isCropRotateMode.toggle()
                if appState.isCropRotateMode && !appState.isInspectorVisible {
                    appState.isInspectorVisible = true
                }
            }) {
                Image(systemName: "crop.rotate")
                    .foregroundColor(appState.isCropRotateMode ? .accentColor : .primary)
            }
            .buttonStyle(.borderless)
            .help("Crop & Rotate")
            
            Button(action: {
                withAnimation { appState.isInspectorVisible.toggle() }
            }) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(appState.isInspectorVisible ? .accentColor : .primary)
            }
            .buttonStyle(.borderless)
            
            Button(action: {
                appState.isFullscreen.toggle()
            }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
            }
            .buttonStyle(.borderless)
            .padding(.trailing, 12)
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }
    
    private func ratingLabel(_ r: Int) -> String {
        switch r {
        case 3: return "Good"
        case 2: return "Maybe"
        case 1: return "Bad"
        default: return "\(r) Stars"
        }
    }
    
    private func ratingColor(_ r: Int) -> Color {
        switch r {
        case 3: return .green
        case 2: return .yellow
        case 1: return .red
        default: return .gray
        }
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
