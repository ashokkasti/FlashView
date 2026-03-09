import Foundation
import AppKit
import ImageIO
import SwiftUI
import CoreImage
import UniformTypeIdentifiers

class ImageProcessor {
    
    static let shared = ImageProcessor()
    
    private let cacheDirectory: URL
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        let fileManager = FileManager.default
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let appCachePath = paths[0].appendingPathComponent("FlashView", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appCachePath.path) {
            try? fileManager.createDirectory(at: appCachePath, withIntermediateDirectories: true, attributes: nil)
        }
        
        self.cacheDirectory = appCachePath
    }
    
    // Generates a thumbnail quickly using ImageIO
    func generateThumbnail(for url: URL, maxPixelSize: Int = 200, completion: @escaping (NSImage?) -> Void) {
        
        // Check memory cache first
        let cacheKey = url.path as NSString
        if let cachedImage = cache.object(forKey: cacheKey) {
            completion(cachedImage)
            return
        }
        
        // Dispatch to background queue for generation
        DispatchQueue.global(qos: .userInitiated).async {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
            ]
            
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let nsImage = NSImage(cgImage: cgImage, size: .zero)
            
            // Cache in memory
            self.cache.setObject(nsImage, forKey: cacheKey)
            
            DispatchQueue.main.async {
                completion(nsImage)
            }
        }
    }
    
    func loadLargeImage(from url: URL) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 3000 // Subsample to roughly screen max bounds
        ]
        
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return NSImage(contentsOf: url) // Fallback immediately
        }
        
        return NSImage(cgImage: cgImage, size: .zero)
    }
    
    func saveEditedImage(url: URL, adjustments: ImageAdjustments) {
        guard let ciImage = CIImage(contentsOf: url) else { return }
        
        var finalImage = ciImage
        
        // Exposure
        if let filter = CIFilter(name: "CIExposureAdjust") {
            filter.setValue(finalImage, forKey: kCIInputImageKey)
            filter.setValue(adjustments.exposure * 2.0, forKey: kCIInputEVKey)
            if let output = filter.outputImage { finalImage = output }
        }
        
        // Saturation & Contrast
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(finalImage, forKey: kCIInputImageKey)
            
            // Replicate simulation saturation mult
            var simSat = 1.0
            switch adjustments.filmSimulation {
            case .velvia: simSat = 1.4
            case .astia: simSat = 0.9
            case .classicChrome: simSat = 0.7
            default: break
            }
            
            filter.setValue(adjustments.saturation * simSat, forKey: kCIInputSaturationKey)
            filter.setValue(adjustments.contrast, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { finalImage = output }
        }
        
        // Film Sim Color
        var multColor: NSColor = .white
        switch adjustments.filmSimulation {
        case .velvia: multColor = NSColor(red: 1.05, green: 1.0, blue: 1.05, alpha: 1.0)
        case .astia: multColor = NSColor(red: 1.0, green: 0.95, blue: 0.95, alpha: 1.0)
        case .classicChrome: multColor = NSColor(red: 0.9, green: 0.95, blue: 0.9, alpha: 1.0)
        default: break
        }
        
        if multColor != .white {
            if let colorFilter = CIFilter(name: "CIColorMultiply") {
                colorFilter.setValue(finalImage, forKey: kCIInputImageKey)
                colorFilter.setValue(CIColor(color: multColor), forKey: "inputColor")
                if let output = colorFilter.outputImage { finalImage = output }
            }
        }
        
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(finalImage, from: finalImage.extent) else { return }
        
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return }
        
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) else {
            CGImageDestinationAddImage(destination, cgImage, nil)
            CGImageDestinationFinalize(destination)
            return
        }
        
        CGImageDestinationAddImage(destination, cgImage, properties)
        CGImageDestinationFinalize(destination)
        
        // Invalidate cache
        cache.removeObject(forKey: url.path as NSString)
    }
}
