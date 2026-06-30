import Foundation
import Combine
import SwiftUI

// Adjustments state for filters
struct ImageAdjustments: Equatable {
    var exposure: Double = 0.0
    var contrast: Double = 1.0
    var saturation: Double = 1.0
    var filmSimulation: FilmSimulation = .none
    
    // Crop & Rotate
    var rotationAngle: Double = 0.0 // degrees, free rotation -45 to +45
    var rotationSteps: Int = 0 // number of 90° CW rotations (0-3)
    var cropRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1) // normalized 0..1
    var isCropped: Bool { cropRect != CGRect(x: 0, y: 0, width: 1, height: 1) }
    var isRotated: Bool { rotationAngle != 0.0 || rotationSteps != 0 }
    
    // Background removal
    var backgroundRemoved: Bool = false
}

enum FilmSimulation: String, CaseIterable, Identifiable {
    case none = "None"
    case provia = "Provia (Standard)"
    case velvia = "Velvia (Vivid)"
    case classicChrome = "Classic Chrome"
    case astia = "Astia (Soft)"
    case eterna = "Eterna (Cinema)"
    case acros = "Acros"
    case acrosRedFilter = "Acros + Red Filter"
    case acrosYellowFilter = "Acros + Yellow Filter"
    case acrosGreenFilter = "Acros + Green Filter"
    case nostalgicNeg = "Nostalgic Neg"
    case proNegHi = "Pro Neg Hi"
    case proNegStd = "Pro Neg Std"
    case classicNeg = "Classic Neg"
    case bleachBypass = "Bleach Bypass"
    case sepia = "Sepia"
    var id: String { self.rawValue }
}

enum AspectRatioPreset: String, CaseIterable, Identifiable {
    case free = "Free"
    case square = "1:1"
    case fourThree = "4:3"
    case sixteenNine = "16:9"
    case threeTwo = "3:2"
    var id: String { self.rawValue }
    
    var ratio: CGFloat? {
        switch self {
        case .free: return nil
        case .square: return 1.0
        case .fourThree: return 4.0 / 3.0
        case .sixteenNine: return 16.0 / 9.0
        case .threeTwo: return 3.0 / 2.0
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case jpeg = "JPEG"
    case png = "PNG"
    case tiff = "TIFF"
    var id: String { self.rawValue }
}

class AppState: ObservableObject {
    @Published var currentFolder: String? = nil
    @Published var images: [URL] = []
    @Published var currentIndex: Int = 0
    @Published var isSlideshowActive: Bool = false
    @Published var isFullscreen: Bool = false
    @Published var isSidebarVisible: Bool = true
    @Published var isInspectorVisible: Bool = false
    
    // Quick Compare Mode
    @Published var isQuickCompareActive: Bool = false
    
    // Grid View State
    @Published var isGridViewActive: Bool = false
    
    // Multi-select state (indices into viewImages)
    @Published var selectedIndices: Set<Int> = []
    @Published var showDeleteSelectionConfirmation: Bool = false
    @Published var showMoveSelectionSheet: Bool = false

    // Feedback
    @Published var toastMessage: String? = nil
    
    // Currently viewed image metadata
    @Published var currentRating: Int? = nil
    
    // Rating cache to avoid constant disk reads and enable fast UI filters
    @Published var imageRatings: [URL: Int] = [:]
    
    // Filtering
    @Published var selectedRatingFilter: Int? = nil
    
    // Editing Adjustments
    @Published var adjustments: ImageAdjustments = ImageAdjustments()
    
    // Processed preview image (CIImage pipeline result)
    @Published var processedPreviewImage: NSImage? = nil
    
    // Crop & Rotate mode
    @Published var isCropRotateMode: Bool = false
    @Published var selectedAspectRatio: AspectRatioPreset = .free
    
    // Export state
    @Published var showExportSheet: Bool = false
    @Published var showSaveConfirmation: Bool = false
    @Published var exportFormat: ExportFormat = .jpeg
    @Published var jpegQuality: Double = 85.0
    
    // Background removal state
    @Published var isRemovingBackground: Bool = false
    
    // Processing state — blocks UI when a heavy filter is being applied
    @Published var isProcessing: Bool = false
    
    // UI State for editing UI
    @Published var isFilmSimulationExpanded: Bool = false
    
    @Published var imageReloadToken: UUID = UUID()
    
    // File Size display
    @Published var currentImageFileSize: String? = nil
    
    // Configuration
    @Published var skipSaveInPlaceConfirmation: Bool = false
    @Published var showDeleteConfirmation: Bool = false
    
    let folderManager: FolderManager
    private var processingTask: DispatchWorkItem?
    private var loadingTask: DispatchWorkItem?
    private var navigationCounter: Int = 0
    
    var viewImages: [URL] {
        if let filter = selectedRatingFilter {
            if filter == 0 {
                return images.filter { (imageRatings[$0] ?? 0) == 0 }
            }
            return images.filter { imageRatings[$0] == filter }
        }
        return images
    }
    
    init(folderManager: FolderManager) {
        self.folderManager = folderManager
    }
    
    func openFile(at url: URL) {
        let parentPath = url.deletingLastPathComponent().path
        folderManager.addRecentFolder(parentPath)
        
        // Open the folder
        openFolder(parentPath)
        
        // Wait for images to load, then select the file
        // Since openFolder is async on main, we can just dispatch after
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let index = self.images.firstIndex(of: url) {
                self.selectImage(at: index)
            }
        }
    }

    
    func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }
    
    func applyRating(_ rating: Int) {
        guard let url = currentImage, let path = currentFolder else { return }
        let normalizedRating: Int? = rating == 0 ? nil : rating
        let oldRating = imageRatings[url]
        MetadataManager.shared.setRating(for: url, rating: normalizedRating)
        
        if let normalizedRating {
            imageRatings[url] = normalizedRating
            currentRating = normalizedRating
        } else {
            imageRatings.removeValue(forKey: url)
            currentRating = nil
        }

        folderManager.updateCount(for: path, oldRating: oldRating, newRating: normalizedRating)
        
        let label: String
        if rating == 3 {
            label = "Good"
        } else if rating == 2 {
            label = "Maybe"
        } else if rating == 1 {
            label = "Bad"
        } else {
            label = "Unrated"
        }
        showToast("Rated: \(label)")
        
        // If image drops out of current filter bucket, don't move next index
        if selectedRatingFilter != nil && !matchesCurrentFilter(normalizedRating) {
            DispatchQueue.main.async {
                let list = self.viewImages
                if self.currentIndex >= list.count {
                    self.currentIndex = max(0, list.count - 1)
                }
                self.updateCurrentMetadata()
                self.adjustments = ImageAdjustments()
            }
        } else {
            nextImage()
        }
    }

    private func matchesCurrentFilter(_ rating: Int?) -> Bool {
        guard let filter = selectedRatingFilter else { return true }
        if filter == 0 {
            return rating == nil || rating == 0
        }
        return rating == filter
    }
    
    // MARK: - Processing Pipeline
    
    func requestPreviewUpdate() {
        processingTask?.cancel()
        processingTask = nil
        
        guard let url = currentImage else {
            processedPreviewImage = nil
            isProcessing = false
            return
        }
        
        let currentAdjustments = adjustments
        let expectedIndex = currentIndex
        
        // Show processing state immediately
        isProcessing = true
        
        var task: DispatchWorkItem!
        task = DispatchWorkItem { [weak self] in
            guard let self = self, !task.isCancelled else { task = nil; return }
            let result = ImageProcessor.shared.processImage(url: url, adjustments: currentAdjustments)
            guard !task.isCancelled else { task = nil; return }
            DispatchQueue.main.async {
                // Only apply if user hasn't navigated away
                guard self.currentIndex == expectedIndex,
                      self.adjustments == currentAdjustments,
                      self.currentImage == url else {
                    self.isProcessing = false
                    self.isRemovingBackground = false
                    return
                }
                self.processedPreviewImage = result
                self.isProcessing = false
                self.isRemovingBackground = false
            }
            task = nil // break retain cycle
        }
        processingTask = task
        ImageProcessor.shared.previewDecodeQueue.asyncAfter(deadline: .now() + 0.06, execute: task)
    }
    
    // MARK: - Background Removal
    
    func toggleBackgroundRemoval() {
        adjustments.backgroundRemoved.toggle()
        if adjustments.backgroundRemoved {
            isRemovingBackground = true
            showToast("Removing background…")
        }
        requestPreviewUpdate()
    }
    
    // MARK: - Save / Export
    
    func saveImageInPlace() {
        guard let url = currentImage else { return }
        let adjust = adjustments
        
        isProcessing = true
        showToast("Saving image...")
        DispatchQueue.global(qos: .userInitiated).async {
            ImageProcessor.shared.saveProcessedImage(url: url, adjustments: adjust, to: url, format: .jpeg, jpegQuality: 0.92)
            DispatchQueue.main.async {
                // Invalidate caches so thumbnail and main image reload fresh
                ImageProcessor.shared.invalidateCache(for: url)
                self.adjustments = ImageAdjustments()
                self.processedPreviewImage = nil
                // Bump reload token to force views to reload
                self.imageReloadToken = UUID()
                self.isProcessing = false
                self.showToast("Image Saved!")
                
                // Update file size
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64 {
                    let formatter = ByteCountFormatter()
                    formatter.allowedUnits = [.useMB, .useKB]
                    formatter.countStyle = .file
                    self.currentImageFileSize = formatter.string(fromByteCount: size)
                }
            }
        }
    }
    
    func exportImage(to destinationURL: URL, format: ExportFormat, quality: Double) {
        guard let url = currentImage else { return }
        let adjust = adjustments
        
        isProcessing = true
        showToast("Exporting...")
        DispatchQueue.global(qos: .userInitiated).async {
            ImageProcessor.shared.saveProcessedImage(url: url, adjustments: adjust, to: destinationURL, format: format, jpegQuality: quality / 100.0)
            DispatchQueue.main.async {
                self.isProcessing = false
                self.showToast("Exported Successfully!")
            }
        }
    }
    
    func saveImageEdits() {
        guard currentImage != nil else { return }
        let adjust = adjustments
        if adjust.exposure == 0 && adjust.contrast == 1 && adjust.saturation == 1
            && adjust.filmSimulation == .none && !adjust.isCropped && !adjust.isRotated
            && !adjust.backgroundRemoved {
            showToast("No edits to save")
            return
        }
        
        if skipSaveInPlaceConfirmation {
            saveImageInPlace()
        } else {
            showSaveConfirmation = true
        }
    }
    
    // MARK: - Export Bucket to ZIP
    
    func exportBucketAsZip(rating: Int?, folderPath: String) {
        let list = bucketImages(rating: rating, folderPath: folderPath)

        guard !list.isEmpty else {
            showToast("Bucket is empty")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.zip]
        let ratingName: String
        if rating == nil {
            ratingName = "All"
        } else if rating == 0 {
            ratingName = "Unrated"
        } else if rating == 3 {
            ratingName = "Good"
        } else if rating == 2 {
            ratingName = "Maybe"
        } else {
            ratingName = "Bad"
        }
        let folderName = (folderPath as NSString).lastPathComponent
        savePanel.nameFieldStringValue = "\(folderName)_\(ratingName)_Photos.zip"
        
        savePanel.begin { response in
            if response == .OK, let zipURL = savePanel.url {
                self.isProcessing = true
                self.showToast("Creating ZIP...")
                
                DispatchQueue.global(qos: .userInitiated).async {
                    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    
                    // Copy files to temp dir first to zip them nicely
                    for url in list {
                        let dest = tempDir.appendingPathComponent(url.lastPathComponent)
                        try? FileManager.default.copyItem(at: url, to: dest)
                    }
                    
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
                    // -j junk paths (don't include directory structure), -r recursive
                    process.arguments = ["-j", zipURL.path] + list.map { url in url.lastPathComponent }
                    process.currentDirectoryURL = tempDir
                    
                    do {
                        try process.run()
                        process.waitUntilExit()
                        DispatchQueue.main.async {
                            self.isProcessing = false
                            self.showToast("Exported Bucket to ZIP!")
                            // Cleanup
                            try? FileManager.default.removeItem(at: tempDir)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.isProcessing = false
                            self.showToast("Failed to create ZIP")
                        }
                    }
                }
            }
        }
    }

    private func bucketImages(rating: Int?, folderPath: String) -> [URL] {
        let urls = folderManager.getImagesInFolder(folderPath)
        guard let rating else { return urls }

        if folderPath == currentFolder {
            if rating == 0 {
                return urls.filter { (imageRatings[$0] ?? 0) == 0 }
            }
            return urls.filter { imageRatings[$0] == rating }
        }

        var ratings: [URL: Int] = [:]
        for url in urls {
            if let value = MetadataManager.shared.getRating(for: url) {
                ratings[url] = value
            }
        }

        if rating == 0 {
            return urls.filter { (ratings[$0] ?? 0) == 0 }
        }
        return urls.filter { ratings[$0] == rating }
    }

    private func bucketName(for rating: Int?) -> String {
        if rating == nil { return "All" }
        if rating == 0 { return "Unrated" }
        if rating == 3 { return "Good" }
        if rating == 2 { return "Maybe" }
        return "Bad"
    }

    func deleteBucketImages(rating: Int?, folderPath: String) {
        let urls = bucketImages(rating: rating, folderPath: folderPath)
        guard !urls.isEmpty else {
            showToast("Bucket is empty")
            return
        }

        let bucketName = bucketName(for: rating)
        let alert = NSAlert()
        alert.messageText = "Move \(urls.count) \(bucketName) photo\(urls.count == 1 ? "" : "s") to Trash?"
        alert.informativeText = "This affects photos in \((folderPath as NSString).lastPathComponent)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async {
            var trashedURLs: [URL] = []
            for url in urls {
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                    ImageProcessor.shared.invalidateCache(for: url)
                    trashedURLs.append(url)
                } catch {
                    print("Failed to trash \(url.lastPathComponent): \(error)")
                }
            }

            DispatchQueue.main.async {
                self.applyTrashedImages(trashedURLs, folderPath: folderPath)
                self.isProcessing = false
                self.showToast("Moved \(trashedURLs.count) photo\(trashedURLs.count == 1 ? "" : "s") to Trash")
            }
        }
    }

    private func applyTrashedImages(_ trashedURLs: [URL], folderPath: String) {
        guard !trashedURLs.isEmpty else { return }

        let trashedSet = Set(trashedURLs)
        imageRatings = imageRatings.filter { !trashedSet.contains($0.key) }

        if currentFolder == folderPath {
            images.removeAll { trashedSet.contains($0) }
            selectedIndices = []

            let list = viewImages
            if currentIndex >= list.count {
                currentIndex = max(0, list.count - 1)
            }
            updateCurrentMetadata()
            adjustments = ImageAdjustments()
            processedPreviewImage = nil
            isCropRotateMode = false
            imageReloadToken = UUID()
            folderManager.loadCounts(for: folderPath, imageRatings: imageRatings)
        } else {
            folderManager.folderCounts[folderPath] = nil
            folderManager.loadCounts(for: folderPath)
        }
    }

    
    func openFolder(_ path: String) {
        let loadedImages = folderManager.getImagesInFolder(path)
        
        DispatchQueue.main.async {
            self.currentFolder = path
            self.images = loadedImages
            self.imageRatings = [:]
            self.selectedIndices = []
            self.selectImage(at: 0)
            self.isSlideshowActive = false
            self.selectedRatingFilter = nil
            self.adjustments = ImageAdjustments()
            self.processedPreviewImage = nil
            self.isCropRotateMode = false
            self.imageReloadToken = UUID()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var ratings: [URL: Int] = [:]
            for url in loadedImages {
                if let r = MetadataManager.shared.getRating(for: url) {
                    ratings[url] = r
                }
            }
            DispatchQueue.main.async {
                self.imageRatings = ratings
                self.updateCurrentMetadata()
                self.folderManager.loadCounts(for: path, imageRatings: ratings)
            }
        }
    }
    
    // MARK: - Refresh Folder
    
    func refreshFolder() {
        guard let path = currentFolder else { return }
        showToast("Refreshing…")
        
        // Clear all caches
        ImageProcessor.shared.clearCache()
        
        let loadedImages = folderManager.getImagesInFolder(path)
        let savedIndex = currentIndex
        
        DispatchQueue.main.async {
            self.images = loadedImages
            self.currentIndex = min(savedIndex, max(0, loadedImages.count - 1))
            self.adjustments = ImageAdjustments()
            self.processedPreviewImage = nil
            self.isCropRotateMode = false
            self.imageReloadToken = UUID()
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var ratings: [URL: Int] = [:]
            for url in loadedImages {
                if let r = MetadataManager.shared.getRating(for: url) {
                    ratings[url] = r
                }
            }
            DispatchQueue.main.async {
                self.imageRatings = ratings
                self.updateCurrentMetadata()
                self.folderManager.loadCounts(for: path, imageRatings: ratings)
                self.showToast("Refreshed!")
            }
        }
    }
    
    func closeFolder() {
        self.currentFolder = nil
        self.images = []
        self.currentIndex = 0
        self.isSlideshowActive = false
        self.processedPreviewImage = nil
        self.isCropRotateMode = false
        ImageProcessor.shared.clearCache()
        ImageProcessor.shared.flushTransientMemory()
    }
    
    var currentImage: URL? {
        let list = viewImages
        guard .init(!list.isEmpty), currentIndex >= 0, currentIndex < list.count else {
            return nil
        }
        return list[currentIndex]
    }
    
    func selectImage(at index: Int) {
        guard index >= 0 && index < viewImages.count else { return }
        
        // Cancel any in-flight processing task before switching images
        processingTask?.cancel()
        processingTask = nil
        
        currentIndex = index
        navigationCounter += 1
        updateCurrentMetadata()
        adjustments = ImageAdjustments()
        isCropRotateMode = false
        processedPreviewImage = nil

        // Aggressively trim thumbnail cache and flush GPU resources on every navigation
        let list = viewImages
        if !list.isEmpty {
            let lower = max(0, index - 15)
            let upper = min(list.count - 1, index + 15)
            let keepURLs = Array(list[lower...upper])

            DispatchQueue.global(qos: .utility).async {
                ImageProcessor.shared.trimThumbnailCache(keeping: keepURLs)
                ImageProcessor.shared.flushTransientMemory()
            }
        }
        
        // Update file size
        if let url = currentImage {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useMB, .useKB]
                formatter.countStyle = .file
                currentImageFileSize = formatter.string(fromByteCount: size)
            }
        }
    }
    
    func nextImage() {
        let list = viewImages
        if currentIndex < list.count - 1 {
            selectImage(at: currentIndex + 1)
        }
    }
    
    func previousImage() {
        if currentIndex > 0 {
            selectImage(at: currentIndex - 1)
        }
    }
    
    func deleteCurrentImage() {
        guard currentImage != nil else { return }
        showDeleteConfirmation = true
    }

    func confirmDeleteCurrentImage() {
        guard let currentUrl = currentImage else {
            showDeleteConfirmation = false
            return
        }
        showDeleteConfirmation = false
        
        do {
            try FileManager.default.trashItem(at: currentUrl, resultingItemURL: nil)
            showToast("Moved to Trash")
            
            let ix = images.firstIndex(of: currentUrl)
            if let indexToRemove = ix {
                images.remove(at: indexToRemove)
            }
            
            let list = viewImages
            if currentIndex >= list.count {
                currentIndex = max(0, list.count - 1)
            }
            updateCurrentMetadata()
            adjustments = ImageAdjustments()
            processedPreviewImage = nil
            isCropRotateMode = false
        } catch {
            print("Failed to trash image: \(error)")
        }
    }
    
    func updateCurrentMetadata() {
        guard let url = currentImage else {
            self.currentRating = nil
            return
        }
        let rating = imageRatings[url]
        self.currentRating = (rating ?? 0) > 0 ? rating : nil
    }
    
    // MARK: - Crop & Rotate Helpers
    
    func rotateLeft90() {
        adjustments.rotationSteps = (adjustments.rotationSteps + 1) % 4
        requestPreviewUpdate()
    }
    
    func rotateRight90() {
        adjustments.rotationSteps = (adjustments.rotationSteps + 3) % 4
        requestPreviewUpdate()
    }
    
    func applyCrop(_ normalizedRect: CGRect) {
        adjustments.cropRect = normalizedRect
        isCropRotateMode = false
        requestPreviewUpdate()
    }
    
    func cancelCropRotate() {
        isCropRotateMode = false
    }
    
    // MARK: - Multi-Select
    
    var hasSelection: Bool { !selectedIndices.isEmpty }
    
    var selectedURLs: [URL] {
        let list = viewImages
        return selectedIndices.sorted().compactMap { i in
            i < list.count ? list[i] : nil
        }
    }
    
    func toggleSelection(at index: Int) {
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
    }
    
    func selectRange(from anchor: Int, to target: Int) {
        let lo = min(anchor, target)
        let hi = max(anchor, target)
        for i in lo...hi { selectedIndices.insert(i) }
    }
    
    func selectAll() {
        selectedIndices = Set(0..<viewImages.count)
    }
    
    func clearSelection() {
        selectedIndices = []
    }
    
    func deleteSelectedImages() {
        guard !selectedIndices.isEmpty else { return }
        showDeleteSelectionConfirmation = true
    }
    
    func confirmDeleteSelectedImages() {
        showDeleteSelectionConfirmation = false
        let urls = selectedURLs
        var removedCount = 0
        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                images.removeAll { $0 == url }
                ImageProcessor.shared.invalidateCache(for: url)
                removedCount += 1
            } catch {
                print("Failed to trash \(url.lastPathComponent): \(error)")
            }
        }
        selectedIndices = []
        let list = viewImages
        if currentIndex >= list.count {
            currentIndex = max(0, list.count - 1)
        }
        updateCurrentMetadata()
        showToast("Moved \(removedCount) photo\(removedCount == 1 ? "" : "s") to Trash")
    }
    
    func moveSelectedImages(to destinationFolder: URL) {
        let urls = selectedURLs
        guard !urls.isEmpty else { return }
        var movedCount = 0
        for url in urls {
            let dest = destinationFolder.appendingPathComponent(url.lastPathComponent)
            do {
                try FileManager.default.moveItem(at: url, to: dest)
                images.removeAll { $0 == url }
                ImageProcessor.shared.invalidateCache(for: url)
                movedCount += 1
            } catch {
                print("Failed to move \(url.lastPathComponent): \(error)")
            }
        }
        selectedIndices = []
        let list = viewImages
        if currentIndex >= list.count {
            currentIndex = max(0, list.count - 1)
        }
        updateCurrentMetadata()
        showToast("Moved \(movedCount) photo\(movedCount == 1 ? "" : "s")")
    }
    
    func rateSelectedImages(_ rating: Int) {
        guard let path = currentFolder else { return }
        let urls = selectedURLs
        let normalizedRating: Int? = rating == 0 ? nil : rating
        for url in urls {
            let oldRating = imageRatings[url]
            MetadataManager.shared.setRating(for: url, rating: normalizedRating)
            if let r = normalizedRating {
                imageRatings[url] = r
            } else {
                imageRatings.removeValue(forKey: url)
            }
            folderManager.updateCount(for: path, oldRating: oldRating, newRating: normalizedRating)
        }
        updateCurrentMetadata()
        let label: String
        switch rating {
        case 3: label = "Good"
        case 2: label = "Maybe"
        case 1: label = "Bad"
        default: label = "Unrated"
        }
        showToast("Rated \(urls.count) photo\(urls.count == 1 ? "" : "s"): \(label)")
    }
    
    func showMovePicker() {
        guard !selectedIndices.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Move Here"
        panel.message = "Choose destination folder for \(selectedIndices.count) photo\(selectedIndices.count == 1 ? "" : "s")"
        panel.begin { response in
            if response == .OK, let dest = panel.url {
                self.moveSelectedImages(to: dest)
            }
        }
    }
    
    // MARK: - Copy and Share Native Functions
    func copyToClipboard(url: URL) {
        let pb = NSPasteboard.general
        pb.clearContents()
        // Write only the file URL — avoids decoding the full image into memory
        pb.writeObjects([url as NSURL])
        showToast("Copied to clipboard")
    }
    
    func copyBucketImages(rating: Int?, folderPath: String) {
        let bucketUrls = bucketImages(rating: rating, folderPath: folderPath)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(bucketUrls as [NSURL])
        showToast("Copied \(bucketUrls.count) items")
    }
    
    func shareItem(url: URL) {
        let sharingPicker = NSSharingServicePicker(items: [url])
        if let window = NSApp.keyWindow, let view = window.contentView {
            sharingPicker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }
}
