import SwiftUI

struct MainPreviewView: View {
    @EnvironmentObject var appState: AppState
    @State private var loadedImage: NSImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).edgesIgnoringSafeArea(.all)
            
            if appState.isCropRotateMode, let image = displayImage {
                CropOverlayView(image: image)
                    .environmentObject(appState)
            } else if let image = displayImage {
                ZStack {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .id(imageId)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.1), value: appState.currentImage)
                    
                    // Invisible overlay to catch scroll events for zoom
                    ScrollDetector { delta in
                        let zoomSpeed: CGFloat = 0.05
                        let newScale = scale + (delta.y * zoomSpeed)
                        scale = max(1.0, min(10.0, newScale))
                        lastScale = scale
                    }
                }
                .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value.magnitude
                            }
                            .onEnded { value in
                                lastScale = scale
                                // Ensure scale doesn't go below 1.0
                                if scale < 1.0 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { value in
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            resetZoom()
                        }
                    }
                    .contextMenu {
                        Button("Good (3)") { appState.applyRating(3) }
                        Button("Maybe (2)") { appState.applyRating(2) }
                        Button("Bad (1)") { appState.applyRating(1) }
                        Divider()
                        Button("Copy Image") {
                            if let url = appState.currentImage {
                                appState.copyToClipboard(url: url)
                            }
                        }
                        Divider()
                        Button("Delete", role: .destructive) { appState.deleteCurrentImage() }
                    }
            } else {
                ProgressView()
            }
            
            // Toast / Feedback Overlay only
            if let toast = appState.toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.title3)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding(.bottom, 20)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: appState.toastMessage)
            }
        }
        .onChange(of: appState.currentImage) { newImage in
            resetZoom()
            loadedImage = nil // Immediate clear for smoother transition
            loadImage(url: newImage)
        }
        .onChange(of: appState.currentIndex) { _ in
            resetZoom()
            loadedImage = nil // Immediate clear
            loadImage(url: appState.currentImage)
        }
        .onChange(of: appState.imageReloadToken) { _ in
            loadImage(url: appState.currentImage)
        }
        .onChange(of: appState.adjustments) { _ in
            appState.requestPreviewUpdate()
        }
        .onAppear {
            loadImage(url: appState.currentImage)
        }
    }
    
    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
    
    /// Use processed image if available (adjustments applied), otherwise raw loaded image
    private var displayImage: NSImage? {
        if hasAdjustments {
            return appState.processedPreviewImage ?? loadedImage
        }
        return loadedImage
    }
    
    private var hasAdjustments: Bool {
        let adj = appState.adjustments
        return adj.exposure != 0 || adj.contrast != 1 || adj.saturation != 1
            || adj.filmSimulation != .none || adj.isCropped || adj.isRotated
            || adj.backgroundRemoved
    }
    
    private var imageId: String {
        let base = appState.currentImage?.absoluteString ?? ""
        let adj = appState.adjustments
        return "\(base)_\(adj.filmSimulation.rawValue)_\(adj.exposure)_\(adj.contrast)_\(adj.saturation)_\(adj.rotationSteps)_\(adj.rotationAngle)_\(adj.backgroundRemoved)"
    }
    
    @State private var loadingTask: DispatchWorkItem?
    
    private func loadImage(url: URL?) {
        loadingTask?.cancel()
        
        guard let url = url else {
            loadedImage = nil
            return
        }
        
        // Small debounce for rapid scrolling
        let task = DispatchWorkItem {
            let img = ImageProcessor.shared.loadLargeImage(from: url)
            DispatchQueue.main.async {
                // Only update if the user hasn't moved to another image yet
                if appState.currentImage == url {
                    self.loadedImage = img
                }
            }
        }
        
        loadingTask = task
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05, execute: task)
    }
}

// MARK: - Crop Overlay View

struct CropOverlayView: View {
    @EnvironmentObject var appState: AppState
    let image: NSImage
    
    @State private var cropRect: CGRect // normalized 0..1
    @State private var dragHandle: CropHandle? = nil
    @State private var dragStartRect: CGRect = .zero
    @State private var dragStartPoint: CGPoint = .zero
    
    enum CropHandle {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
        case move
    }
    
    init(image: NSImage) {
        self.image = image
        _cropRect = State(initialValue: CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let imageFrame = imageDisplayFrame(in: geometry.size)
            
            ZStack {
                // Background image (dimmed)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .position(x: imageFrame.midX, y: imageFrame.midY)
                    .opacity(0.4)
                
                // Cropped region (full brightness)
                let cropPixelRect = denormalizeCropRect(cropRect, imageFrame: imageFrame)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .position(x: imageFrame.midX, y: imageFrame.midY)
                    .clipShape(
                        Rectangle()
                            .offset(x: cropPixelRect.minX - imageFrame.minX, y: cropPixelRect.minY - imageFrame.minY)
                            .size(width: cropPixelRect.width, height: cropPixelRect.height)
                    )
                
                // Crop border
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: cropPixelRect.width, height: cropPixelRect.height)
                    .position(x: cropPixelRect.midX, y: cropPixelRect.midY)
                
                // Rule of thirds grid
                let w = cropPixelRect.width
                let h = cropPixelRect.height
                Path { path in
                    for i in 1...2 {
                        let x = cropPixelRect.minX + w * CGFloat(i) / 3.0
                        path.move(to: CGPoint(x: x, y: cropPixelRect.minY))
                        path.addLine(to: CGPoint(x: x, y: cropPixelRect.maxY))
                    }
                    for i in 1...2 {
                        let y = cropPixelRect.minY + h * CGFloat(i) / 3.0
                        path.move(to: CGPoint(x: cropPixelRect.minX, y: y))
                        path.addLine(to: CGPoint(x: cropPixelRect.maxX, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                
                // Corner handles
                ForEach(cornerHandles(in: cropPixelRect), id: \.handle) { handleInfo in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(radius: 2)
                        .position(handleInfo.position)
                }
                
                // Drag gesture over entire area
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                handleDrag(value, imageFrame: imageFrame)
                            }
                            .onEnded { _ in
                                dragHandle = nil
                            }
                    )
                    .onAppear {
                        cropRect = appState.adjustments.cropRect
                    }
                
                // Bottom toolbar
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Picker("Ratio", selection: $appState.selectedAspectRatio) {
                            ForEach(AspectRatioPreset.allCases) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 350)
                        
                        Spacer()
                        
                        Button("Cancel") {
                            appState.cancelCropRotate()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Apply Crop") {
                            appState.applyCrop(cropRect)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
        }
    }
    
    private struct HandleInfo: Identifiable {
        let handle: CropHandle
        let position: CGPoint
        var id: String {
            switch handle {
            case .topLeft: return "tl"
            case .topRight: return "tr"
            case .bottomLeft: return "bl"
            case .bottomRight: return "br"
            default: return "other"
            }
        }
    }
    
    private func cornerHandles(in rect: CGRect) -> [HandleInfo] {
        return [
            HandleInfo(handle: .topLeft, position: CGPoint(x: rect.minX, y: rect.minY)),
            HandleInfo(handle: .topRight, position: CGPoint(x: rect.maxX, y: rect.minY)),
            HandleInfo(handle: .bottomLeft, position: CGPoint(x: rect.minX, y: rect.maxY)),
            HandleInfo(handle: .bottomRight, position: CGPoint(x: rect.maxX, y: rect.maxY))
        ]
    }
    
    private func imageDisplayFrame(in containerSize: CGSize) -> CGRect {
        let imageSize = image.size
        let widthRatio = containerSize.width / imageSize.width
        let heightRatio = containerSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio)
        
        let displayWidth = imageSize.width * scale
        let displayHeight = imageSize.height * scale
        let offsetX = (containerSize.width - displayWidth) / 2
        let offsetY = (containerSize.height - displayHeight) / 2
        
        return CGRect(x: offsetX, y: offsetY, width: displayWidth, height: displayHeight)
    }
    
    private func denormalizeCropRect(_ normalized: CGRect, imageFrame: CGRect) -> CGRect {
        return CGRect(
            x: imageFrame.origin.x + normalized.origin.x * imageFrame.width,
            y: imageFrame.origin.y + normalized.origin.y * imageFrame.height,
            width: normalized.width * imageFrame.width,
            height: normalized.height * imageFrame.height
        )
    }
    
    private func normalizePoint(_ point: CGPoint, imageFrame: CGRect) -> CGPoint {
        return CGPoint(
            x: (point.x - imageFrame.origin.x) / imageFrame.width,
            y: (point.y - imageFrame.origin.y) / imageFrame.height
        )
    }
    
    private func handleDrag(_ value: DragGesture.Value, imageFrame: CGRect) {
        let normalizedPoint = normalizePoint(value.location, imageFrame: imageFrame)
        let normalizedStart = normalizePoint(value.startLocation, imageFrame: imageFrame)
        
        if dragHandle == nil {
            dragStartRect = cropRect
            dragStartPoint = normalizedStart
            
            let handleRadius: CGFloat = 30 / max(imageFrame.width, imageFrame.height)
            
            let corners: [(CropHandle, CGPoint)] = [
                (.topLeft, CGPoint(x: cropRect.minX, y: cropRect.minY)),
                (.topRight, CGPoint(x: cropRect.maxX, y: cropRect.minY)),
                (.bottomLeft, CGPoint(x: cropRect.minX, y: cropRect.maxY)),
                (.bottomRight, CGPoint(x: cropRect.maxX, y: cropRect.maxY))
            ]
            
            for (handle, pos) in corners {
                if distance(normalizedStart, pos) < handleRadius {
                    dragHandle = handle
                    return
                }
            }
            
            let edges: [(CropHandle, () -> Bool)] = [
                (.top, { abs(normalizedStart.y - cropRect.minY) < handleRadius && normalizedStart.x > cropRect.minX && normalizedStart.x < cropRect.maxX }),
                (.bottom, { abs(normalizedStart.y - cropRect.maxY) < handleRadius && normalizedStart.x > cropRect.minX && normalizedStart.x < cropRect.maxX }),
                (.left, { abs(normalizedStart.x - cropRect.minX) < handleRadius && normalizedStart.y > cropRect.minY && normalizedStart.y < cropRect.maxY }),
                (.right, { abs(normalizedStart.x - cropRect.maxX) < handleRadius && normalizedStart.y > cropRect.minY && normalizedStart.y < cropRect.maxY })
            ]
            
            for (handle, check) in edges {
                if check() {
                    dragHandle = handle
                    return
                }
            }
            
            if cropRect.contains(normalizedStart) {
                dragHandle = .move
            }
        }
        
        guard let handle = dragHandle else { return }
        
        let dx = normalizedPoint.x - dragStartPoint.x
        let dy = normalizedPoint.y - dragStartPoint.y
        let r = dragStartRect
        let minSize: CGFloat = 0.05
        
        var newRect = r
        
        switch handle {
        case .topLeft:
            newRect = CGRect(
                x: min(r.maxX - minSize, max(0, r.minX + dx)),
                y: min(r.maxY - minSize, max(0, r.minY + dy)),
                width: max(minSize, r.width - dx),
                height: max(minSize, r.height - dy)
            )
        case .topRight:
            newRect = CGRect(
                x: r.minX,
                y: min(r.maxY - minSize, max(0, r.minY + dy)),
                width: max(minSize, min(1 - r.minX, r.width + dx)),
                height: max(minSize, r.height - dy)
            )
        case .bottomLeft:
            newRect = CGRect(
                x: min(r.maxX - minSize, max(0, r.minX + dx)),
                y: r.minY,
                width: max(minSize, r.width - dx),
                height: max(minSize, min(1 - r.minY, r.height + dy))
            )
        case .bottomRight:
            newRect = CGRect(
                x: r.minX,
                y: r.minY,
                width: max(minSize, min(1 - r.minX, r.width + dx)),
                height: max(minSize, min(1 - r.minY, r.height + dy))
            )
        case .top:
            newRect = CGRect(
                x: r.minX,
                y: min(r.maxY - minSize, max(0, r.minY + dy)),
                width: r.width,
                height: max(minSize, r.height - dy)
            )
        case .bottom:
            newRect = CGRect(
                x: r.minX,
                y: r.minY,
                width: r.width,
                height: max(minSize, min(1 - r.minY, r.height + dy))
            )
        case .left:
            newRect = CGRect(
                x: min(r.maxX - minSize, max(0, r.minX + dx)),
                y: r.minY,
                width: max(minSize, r.width - dx),
                height: r.height
            )
        case .right:
            newRect = CGRect(
                x: r.minX,
                y: r.minY,
                width: max(minSize, min(1 - r.minX, r.width + dx)),
                height: r.height
            )
        case .move:
            let newX = max(0, min(1 - r.width, r.minX + dx))
            let newY = max(0, min(1 - r.height, r.minY + dy))
            newRect = CGRect(x: newX, y: newY, width: r.width, height: r.height)
        }
        
        // Constrain aspect ratio if set
        if let ratio = appState.selectedAspectRatio.ratio, handle != .move {
            let currentRatio = newRect.width / newRect.height
            if currentRatio > ratio {
                newRect.size.width = newRect.height * ratio
            } else {
                newRect.size.height = newRect.width / ratio
            }
        }
        
        newRect = clampRect(newRect)
        cropRect = newRect
    }
    
    private func clampRect(_ rect: CGRect) -> CGRect {
        var r = rect
        r.origin.x = max(0, r.origin.x)
        r.origin.y = max(0, r.origin.y)
        if r.maxX > 1 { r.origin.x = 1 - r.width }
        if r.maxY > 1 { r.origin.y = 1 - r.height }
        return r
    }
    
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2))
    }
}
