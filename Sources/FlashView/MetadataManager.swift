import Foundation
import AppKit

class MetadataManager {
    static let shared = MetadataManager()
    private let persistIntoImageMetadata = false
    
    // Reads XMP/IPTC Rating if available or Xattr
    func getRating(for url: URL) -> Int? {
        // 1. Check xattr first (fastest)
        var ratingValue: Int = 0
        let xattrName = "com.apple.metadata:kMDItemStarRating"
        let size = url.withUnsafeFileSystemRepresentation { fileSystemPath -> Int in
            if let path = fileSystemPath {
                return getxattr(path, xattrName, &ratingValue, MemoryLayout<Int>.size, 0, 0)
            }
            return -1
        }
        if size == MemoryLayout<Int>.size {
            return ratingValue
        }
        
        // 2. Check metadata
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        
        if let iptcDict = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any],
           let rating = iptcDict["StarRating"] as? Int {
            return rating
        }
        
        return nil
    }
    
    // Writes rating (1-5) to xattr, or clears rating when nil/0.
    func setRating(for url: URL, rating: Int?) {
        let normalizedRating = ((rating ?? 0) > 0) ? rating : nil

        // Run on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let type = CGImageSourceGetType(source) else {
                return
            }
            
            // Get original metadata
            guard let metadataDict = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
                return
            }
            
            // Insert or update TIFF rating (Standard EXIF/TIFF doesn't have a 100% standard rating, 
            // but often people use IPTC or XMP. We'll use IPTC and custom XMP dictionary keys.
            // For simplicity in MVP, we might just store it in macOS extended attributes if CGImageDestination is too slow/destructive.
            // Let's use file extended attributes (xattr) for instant performance, and maybe EXIF later.
            
            let xattrName = "com.apple.metadata:kMDItemStarRating"

            url.withUnsafeFileSystemRepresentation { fileSystemPath in
                if let path = fileSystemPath {
                    if let normalizedRating {
                        var ratingValue = normalizedRating
                        let ratingData = Data(bytes: &ratingValue, count: MemoryLayout<Int>.size)
                        setxattr(path, xattrName, (ratingData as NSData).bytes, ratingData.count, 0, 0)
                    } else {
                        removexattr(path, xattrName, 0)
                    }
                }
            }

            guard self.persistIntoImageMetadata,
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let type = CGImageSourceGetType(source),
                  let metadataDict = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
                return
            }

            self.writeDestructiveMetadata(url: url, type: type, source: source, metadata: metadataDict, rating: normalizedRating)
        }
    }
    
    private func writeDestructiveMetadata(url: URL, type: CFString, source: CGImageSource, metadata: [String: Any], rating: Int?) {
        let tempURL = url.appendingPathExtension("tmp")
        
        guard let dest = CGImageDestinationCreateWithURL(tempURL as CFURL, type, 1, nil) else { return }
        
        var newMetadata = metadata
        
        // Try to inject IPTC or TIFF based rating
        var iptcDict = newMetadata[kCGImagePropertyIPTCDictionary as String] as? [String: Any] ?? [:]
        if let rating {
            iptcDict["StarRating"] = rating
            newMetadata[kCGImagePropertyIPTCDictionary as String] = iptcDict
        } else {
            iptcDict.removeValue(forKey: "StarRating")
            if iptcDict.isEmpty {
                newMetadata.removeValue(forKey: kCGImagePropertyIPTCDictionary as String)
            } else {
                newMetadata[kCGImagePropertyIPTCDictionary as String] = iptcDict
            }
        }
        
        CGImageDestinationAddImageFromSource(dest, source, 0, newMetadata as CFDictionary)
        
        if CGImageDestinationFinalize(dest) {
            do {
                _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
                if let rating {
                    print("Successfully wrote rating \(rating) to \(url.lastPathComponent)")
                } else {
                    print("Successfully removed rating from \(url.lastPathComponent)")
                }
            } catch {
                print("Failed to replace file: \(error)")
            }
        }
    }
}
