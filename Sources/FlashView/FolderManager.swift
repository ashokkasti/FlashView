import Foundation
import AppKit
import SwiftUI

class FolderManager: ObservableObject {
    @Published var recentFolders: [String] = []
    
    private let maxRecentFolders = 10
    private let recentFoldersKey = "RecentFolders"
    
    init() {
        loadRecentFolders()
    }
    
    func loadRecentFolders() {
        if let storedFolders = UserDefaults.standard.stringArray(forKey: recentFoldersKey) {
            // Filter out folders that no longer exist
            self.recentFolders = storedFolders.filter { FileManager.default.fileExists(atPath: $0) }
            saveRecentFolders() // Update in case any were removed
        }
    }
    
    func saveRecentFolders() {
        UserDefaults.standard.set(recentFolders, forKey: recentFoldersKey)
    }
    
    func addRecentFolder(_ path: String) {
        var folders = recentFolders
        
        // Remove if it already exists to move it to the top
        if let index = folders.firstIndex(of: path) {
            folders.remove(at: index)
        }
        
        folders.insert(path, at: 0)
        
        if folders.count > maxRecentFolders {
            folders = Array(folders.prefix(maxRecentFolders))
        }
        
        self.recentFolders = folders
        saveRecentFolders()
    }
    
    func removeRecentFolder(_ path: String) {
        if let index = recentFolders.firstIndex(of: path) {
            recentFolders.remove(at: index)
            saveRecentFolders()
        }
    }
    
    func openFolderPicker(completion: @escaping (String?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Folder"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                let path = url.path
                addRecentFolder(path)
                completion(path)
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }
    
    func getImagesInFolder(_ path: String) -> [URL] {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            // Supported extensions
            let extensions = ["jpg", "jpeg", "png", "heic", "tiff"]
            
            let images = contents.filter { url in
                extensions.contains(url.pathExtension.lowercased())
            }
            
            // Sort alphabetically for consistency
            return images.sorted { $0.lastPathComponent < $1.lastPathComponent }
            
        } catch {
            print("Error reading directory: \(error)")
            return []
        }
    }
    
    @Published var folderCounts: [String: [Int: Int]] = [:]
    
    func loadCounts(for path: String, imageRatings: [URL: Int]? = nil) {
        if let ratings = imageRatings {
            let total = getImagesInFolder(path).count
            var counts = [0: total]
            for r in ratings.values { counts[r, default: 0] += 1 }
            folderCounts[path] = counts
        } else {
            // Check if we already have it
            if folderCounts[path] != nil { return }
            
            DispatchQueue.global(qos: .userInitiated).async {
                let images = self.getImagesInFolder(path)
                var counts = [0: images.count]
                for url in images {
                    if let r = MetadataManager.shared.getRating(for: url) {
                        counts[r, default: 0] += 1
                    }
                }
                DispatchQueue.main.async { self.folderCounts[path] = counts }
            }
        }
    }
    
    func updateCount(for path: String, oldRating: Int?, newRating: Int?) {
        var counts = folderCounts[path] ?? [0: getImagesInFolder(path).count]
        if let old = oldRating {
            counts[old] = max(0, (counts[old] ?? 0) - 1)
        }
        if let new = newRating {
            counts[new] = (counts[new] ?? 0) + 1
        }
        folderCounts[path] = counts
    }
}
