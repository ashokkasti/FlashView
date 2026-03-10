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
    
    // Image reload token — bumped to force reload of main image and thumbnails
    @Published var imageReloadToken: UUID = UUID()
    
    let folderManager: FolderManager
    private var processingTask: DispatchWorkItem?
    
    var viewImages: [URL] {
        if let filter = selectedRatingFilter {
            return images.filter { imageRatings[$0] == filter }
        }
        return images
    }
    
    init(folderManager: FolderManager) {
        self.folderManager = folderManager
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
        let oldRating = imageRatings[url]
        MetadataManager.shared.setRating(for: url, rating: rating)
        
        imageRatings[url] = rating
        currentRating = rating
        folderManager.updateCount(for: path, oldRating: oldRating, newRating: rating)
        
        let label = rating == 3 ? "Good" : (rating == 2 ? "Maybe" : "Bad")
        showToast("Rated: \(label)")
        
        // If image drops out of current filter bucket, don't move next index
        if selectedRatingFilter != nil && selectedRatingFilter != rating {
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
    
    // MARK: - Processing Pipeline
    
    func requestPreviewUpdate() {
        processingTask?.cancel()
        
        guard let url = currentImage else {
            processedPreviewImage = nil
            isProcessing = false
            return
        }
        
        let currentAdjustments = adjustments
        
        // Show processing state immediately
        isProcessing = true
        
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let result = ImageProcessor.shared.processImage(url: url, adjustments: currentAdjustments)
            DispatchQueue.main.async {
                if self.adjustments == currentAdjustments && self.currentImage == url {
                    self.processedPreviewImage = result
                }
                self.isProcessing = false
                self.isRemovingBackground = false
            }
        }
        processingTask = task
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.06, execute: task)
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
        showSaveConfirmation = true
    }
    
    func openFolder(_ path: String) {
        let loadedImages = folderManager.getImagesInFolder(path)
        
        DispatchQueue.main.async {
            self.currentFolder = path
            self.images = loadedImages
            self.imageRatings = [:]
            self.currentIndex = 0
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
        currentIndex = index
        updateCurrentMetadata()
        adjustments = ImageAdjustments()
        isCropRotateMode = false
        processedPreviewImage = nil
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
        guard let currentUrl = currentImage else { return }
        
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
        self.currentRating = imageRatings[url]
    }
    
    // MARK: - Crop & Rotate Helpers
    
    func rotateLeft90() {
        adjustments.rotationSteps = (adjustments.rotationSteps + 3) % 4
        requestPreviewUpdate()
    }
    
    func rotateRight90() {
        adjustments.rotationSteps = (adjustments.rotationSteps + 1) % 4
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
}
