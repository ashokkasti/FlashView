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
                        .zIndex(1)
                    
                    if appState.viewImages.isEmpty {
                        EmptyStateView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if appState.isGridViewActive {
                        ImageGridView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
                    } else {
                        GeometryReader { geometry in
                            VStack(spacing: 0) {
                                MainPreviewView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(VisualEffectView(material: .underPageBackground, blendingMode: .behindWindow))
                                
                                if !appState.isFullscreen {
                                    ThumbnailStripView()
                                        .frame(height: 140)
                                }
                            }
                            .clipped()
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
                    
                    // Save shortcut
                    Button("") { appState.saveImageEdits() }.keyboardShortcut("s", modifiers: [.command])
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
        HStack(spacing: 16) {
            Button(action: {
                withAnimation { appState.isSidebarVisible.toggle() }
            }) {
                Image(systemName: "sidebar.left")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            
            // Full folder path
            if let folder = appState.currentFolder {
                HStack(spacing: 4) {
                    Text((folder as NSString).lastPathComponent)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let filter = appState.selectedRatingFilter {
                        Text("›")
                            .foregroundColor(.secondary)
                        Text(ratingLabel(filter))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // File name in the center
            if let url = appState.currentImage, !appState.isGridViewActive {
                VStack(spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        
                    if let size = appState.currentImageFileSize {
                        Text(size)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Rating tag
            if let r = appState.currentRating, !appState.isGridViewActive {
                Text(ratingLabel(r))
                    .font(.caption).bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ratingColor(r))
                    .cornerRadius(8)
                    .foregroundColor(r == 2 ? .black : .white)
            }
            
            Spacer()
            
            // Icons on Right
            HStack(spacing: 16) {
                if !appState.viewImages.isEmpty {
                    Text("\(appState.currentIndex + 1)/\(appState.viewImages.count)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    withAnimation { appState.isGridViewActive.toggle() }
                }) {
                    Image(systemName: appState.isGridViewActive ? "photo" : "square.grid.2x2")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Toggle Grid View")
                
                Button(action: {
                    appState.refreshFolder()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Refresh folder (⌘R)")
                
                Button(action: {
                    appState.isCropRotateMode.toggle()
                    if appState.isCropRotateMode && !appState.isInspectorVisible {
                        appState.isInspectorVisible = true
                    }
                }) {
                    Image(systemName: "crop.rotate")
                        .font(.title3)
                        .foregroundColor(appState.isCropRotateMode ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .help("Crop & Rotate")
                
                Button(action: {
                    withAnimation { appState.isInspectorVisible.toggle() }
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(appState.isInspectorVisible ? .accentColor : .primary)
                }
                .buttonStyle(.plain)
                .help("Show Adjustments")
                
                Button(action: {
                    appState.isFullscreen.toggle()
                }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
        .background(VisualEffectView(material: .titlebar, blendingMode: .withinWindow))
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
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow))
    }
}

// MARK: - Grid View
struct ImageGridView: View {
    @EnvironmentObject var appState: AppState
    
    let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 20)]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(Array(appState.viewImages.enumerated()), id: \.element) { index, url in
                    VStack(spacing: 8) {
                        ThumbnailItemView(
                            url: url,
                            isSelected: index == appState.currentIndex,
                            rating: appState.imageRatings[url],
                            reloadToken: appState.imageReloadToken
                        )
                        .frame(height: 140)
                        
                        Text(url.lastPathComponent)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(8)
                    .background(index == appState.currentIndex ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.selectImage(at: index)
                        withAnimation { appState.isGridViewActive = false }
                    }
                    .contextMenu {
                        Button("Copy Image") { appState.copyToClipboard(url: url) }
                        Button("Share") { appState.shareItem(url: url) }
                    }
                }
            }
            .padding(24)
        }
    }
}
