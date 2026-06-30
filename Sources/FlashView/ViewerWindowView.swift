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
                    
                    // Rating shortcuts — dynamically generated from config
                    Button("") { appState.applyRating(0) }.keyboardShortcut("0", modifiers: [])
                    ForEach(RatingConfig.shared.sortedLabels) { label in
                        if !label.shortcut.isEmpty, let char = label.shortcut.first {
                            Button("") { appState.applyRating(label.value) }
                                .keyboardShortcut(KeyEquivalent(char), modifiers: [])
                        }
                    }
                    
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
            .alert("Delete this photo?", isPresented: $appState.showDeleteConfirmation) {
                Button("Yes", role: .destructive) {
                    appState.confirmDeleteCurrentImage()
                }
                .keyboardShortcut(.defaultAction)

                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will move the current photo to Trash.")
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
    @State private var showRatingSettings = false
    
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
                let bgColor = ratingColor(r)
                Text(ratingLabel(r))
                    .font(.caption).bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(bgColor)
                    .cornerRadius(8)
                    .foregroundColor(bgColor.readableTextColor)
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
                    if !appState.isGridViewActive {
                        appState.clearSelection()
                    }
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
                
                Button(action: { showRatingSettings = true }) {
                    Image(systemName: "tag")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Rating Labels")
                .popover(isPresented: $showRatingSettings) {
                    RatingSettingsView()
                }
                
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
        RatingConfig.shared.name(for: r)
    }
    
    private func ratingColor(_ r: Int) -> Color {
        RatingConfig.shared.color(for: r)
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
    // Tracks the last tapped index for shift-range selection
    @State private var lastTappedIndex: Int? = nil
    
    let columns = [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 20)]
    
    var body: some View {
        VStack(spacing: 0) {
            // Multi-select action bar — shown when items are selected
            if appState.hasSelection {
                MultiSelectActionBar(lastTappedIndex: $lastTappedIndex)
            }
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 24) {
                    let urls = appState.viewImages
                    ForEach(urls.indices, id: \.self) { index in
                        let url = urls[index]
                        let isSelected = appState.selectedIndices.contains(index)
                        let isCurrent = index == appState.currentIndex
                        
                        VStack(spacing: 8) {
                            ZStack(alignment: .topTrailing) {
                                ThumbnailItemView(
                                    url: url,
                                    isSelected: isCurrent && !appState.hasSelection,
                                    rating: appState.imageRatings[url],
                                    reloadToken: appState.imageReloadToken
                                )
                                .frame(height: 140)
                                
                                // Checkmark badge for multi-select
                                if appState.hasSelection {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(isSelected ? .accentColor : .white.opacity(0.8))
                                        .shadow(radius: 2)
                                        .padding(6)
                                }
                            }
                            
                            Text(url.lastPathComponent)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(8)
                        .background(
                            isSelected
                                ? Color.accentColor.opacity(0.25)
                                : (isCurrent && !appState.hasSelection ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleTap(index: index)
                        }
                        .contextMenu {
                            if appState.hasSelection && appState.selectedIndices.contains(index) {
                                // Multi-select context menu
                                Text("\(appState.selectedIndices.count) photos selected")
                                    .foregroundColor(.secondary)
                                Divider()
                                Menu("Rate Selected") {
                                    ForEach(RatingConfig.shared.sortedLabels) { label in
                                        Button("\(label.name) (\(label.value))") { appState.rateSelectedImages(label.value) }
                                    }
                                    Button("Unrate (0)") { appState.rateSelectedImages(0) }
                                }
                                Button("Move Selected…") { appState.showMovePicker() }
                                Divider()
                                Button("Deselect All") { appState.clearSelection() }
                                Divider()
                                Button("Delete Selected", role: .destructive) {
                                    appState.deleteSelectedImages()
                                }
                            } else {
                                Button("Open") {
                                    appState.selectImage(at: index)
                                    withAnimation { appState.isGridViewActive = false }
                                }
                                Button("Copy Image") { appState.copyToClipboard(url: url) }
                                Button("Share") { appState.shareItem(url: url) }
                                Divider()
                                Button("Select") {
                                    appState.toggleSelection(at: index)
                                    lastTappedIndex = index
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
        }
        // Cmd+A = select all
        .background(
            Button("") { appState.selectAll() }
                .keyboardShortcut("a", modifiers: [.command])
                .opacity(0)
        )
        // Escape = clear selection
        .background(
            Button("") {
                if appState.hasSelection {
                    appState.clearSelection()
                    lastTappedIndex = nil
                }
            }
            .keyboardShortcut(.escape, modifiers: [])
            .opacity(0)
        )
        .alert("Delete \(appState.selectedIndices.count) photo\(appState.selectedIndices.count == 1 ? "" : "s")?",
               isPresented: $appState.showDeleteSelectionConfirmation) {
            Button("Delete", role: .destructive) {
                appState.confirmDeleteSelectedImages()
                lastTappedIndex = nil
            }
            .keyboardShortcut(.defaultAction)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will move the selected photos to Trash.")
        }
    }
    
    private func handleTap(index: Int) {
        let modifiers = NSEvent.modifierFlags
        
        if modifiers.contains(.command) {
            // Cmd+click: toggle individual item
            appState.toggleSelection(at: index)
            lastTappedIndex = index
        } else if modifiers.contains(.shift), let anchor = lastTappedIndex {
            // Shift+click: range select
            appState.selectRange(from: anchor, to: index)
            lastTappedIndex = index
        } else if appState.hasSelection {
            // Plain click while in multi-select mode: toggle item
            appState.toggleSelection(at: index)
            lastTappedIndex = index
        } else {
            // Plain click with no selection: navigate to image
            appState.selectImage(at: index)
            withAnimation { appState.isGridViewActive = false }
        }
    }
}

// MARK: - Multi-Select Action Bar
struct MultiSelectActionBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var lastTappedIndex: Int?
    
    var body: some View {
        HStack(spacing: 16) {
            Text("\(appState.selectedIndices.count) selected")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            // Rate menu
            Menu {
                ForEach(RatingConfig.shared.sortedLabels) { label in
                    Button("\(label.name) (\(label.value))") { appState.rateSelectedImages(label.value) }
                }
                Button("Unrate") { appState.rateSelectedImages(0) }
            } label: {
                Label("Rate", systemImage: "star")
                    .font(.subheadline)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Button {
                appState.showMovePicker()
            } label: {
                Label("Move", systemImage: "folder")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            
            Button {
                appState.deleteSelectedImages()
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.subheadline)
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
            
            Button {
                appState.clearSelection()
                lastTappedIndex = nil
            } label: {
                Text("Deselect All")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(VisualEffectView(material: .titlebar, blendingMode: .withinWindow))
        .overlay(Divider(), alignment: .bottom)
    }
}
