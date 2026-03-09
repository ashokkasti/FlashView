import Foundation
import Combine
import SwiftUI

// Adjustments state for filters
struct ImageAdjustments: Equatable {
    var exposure: Double = 0.0
    var contrast: Double = 1.0
    var saturation: Double = 1.0
    var filmSimulation: FilmSimulation = .none
}

enum FilmSimulation: String, CaseIterable, Identifiable {
    case none = "None"
    case provia = "Provia (Standard)"
    case velvia = "Velvia (Vivid)"
    case astia = "Astia (Soft)"
    case classicChrome = "Classic Chrome"
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
    
    let folderManager: FolderManager
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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
        
        // If image drops out of current filter bucket, don't move next index, just stay so next image shifts in
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
    
    func saveImageEdits() {
        guard let url = currentImage else { return }
        let adjust = adjustments
        if adjust.exposure == 0 && adjust.contrast == 1 && adjust.saturation == 1 && adjust.filmSimulation == .none {
            showToast("No edits to save")
            return
        }
        
        showToast("Saving image...")
        DispatchQueue.global(qos: .userInitiated).async {
            ImageProcessor.shared.saveEditedImage(url: url, adjustments: adjust)
            DispatchQueue.main.async {
                self.showToast("Image Saved!")
            }
        }
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
        }
        
        // Background load ratings
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
    
    func closeFolder() {
        self.currentFolder = nil
        self.images = []
        self.currentIndex = 0
        self.isSlideshowActive = false
    }
    
    var currentImage: URL? {
        let list = viewImages
        guard .init(!list.isEmpty), currentIndex >= 0, currentIndex < list.count else {
            return nil
        }
        return list[currentIndex]
    }
    
    func nextImage() {
        let list = viewImages
        if currentIndex < list.count - 1 {
            currentIndex += 1
            updateCurrentMetadata()
            adjustments = ImageAdjustments() // Reset per image
        }
    }
    
    func previousImage() {
        if currentIndex > 0 {
            currentIndex -= 1
            updateCurrentMetadata()
            adjustments = ImageAdjustments() // Reset per image
        }
    }
    
    func deleteCurrentImage() {
        guard let currentUrl = currentImage else { return }
        
        do {
            try FileManager.default.trashItem(at: currentUrl, resultingItemURL: nil)
            showToast("Moved to Trash")
            
            // Refilter and index
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
}

