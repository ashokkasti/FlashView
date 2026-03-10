import Foundation
import AppKit
import ImageIO
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers
import Vision

class ImageProcessor {
    
    static let shared = ImageProcessor()
    
    private let cacheDirectory: URL
    private let cache = NSCache<NSString, NSImage>()
    
    // Singleton CIContext — expensive to create, GPU/ANE backed
    let ciContext: CIContext = {
        return CIContext(options: [
            .useSoftwareRenderer: false,
            .highQualityDownsample: true
        ])
    }()
    
    private init() {
        let fileManager = FileManager.default
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let appCachePath = paths[0].appendingPathComponent("FlashView", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appCachePath.path) {
            try? fileManager.createDirectory(at: appCachePath, withIntermediateDirectories: true, attributes: nil)
        }
        
        self.cacheDirectory = appCachePath
    }
    
    // MARK: - Cache Management
    
    /// Remove a specific URL from the thumbnail cache
    func invalidateCache(for url: URL) {
        cache.removeObject(forKey: url.path as NSString)
    }
    
    /// Clear all cached thumbnails
    func clearCache() {
        cache.removeAllObjects()
    }
    
    // MARK: - Thumbnail Generation
    
    func generateThumbnail(for url: URL, maxPixelSize: Int = 200, completion: @escaping (NSImage?) -> Void) {
        
        let cacheKey = url.path as NSString
        if let cachedImage = cache.object(forKey: cacheKey) {
            completion(cachedImage)
            return
        }
        
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
            self.cache.setObject(nsImage, forKey: cacheKey)
            
            DispatchQueue.main.async {
                completion(nsImage)
            }
        }
    }
    
    func loadLargeImage(from url: URL) -> NSImage? {
        // Use CIImage to ensure high quality and consistency with the processing pipeline
        // Explicitly apply orientation from metadata so it matches the thumbnail
        guard var ciImage = CIImage(contentsOf: url)?.oriented(forExifOrientation: getExifOrientation(url: url)) else {
            return NSImage(contentsOf: url) // Minimal fallback
        }
        
        let outputExtent = ciImage.extent
        let maxDim: CGFloat = 4096
        
        if outputExtent.width > maxDim || outputExtent.height > maxDim {
            let scale = maxDim / max(outputExtent.width, outputExtent.height)
            if let filter = CIFilter(name: "CILanczosScaleTransform") {
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(scale, forKey: kCIInputScaleKey)
                if let output = filter.outputImage {
                    ciImage = output
                }
            }
        }
        
        let finalExtent = ciImage.extent
        guard let cgImage = ciContext.createCGImage(ciImage, from: finalExtent) else {
            return NSImage(contentsOf: url)
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    // MARK: - Full CIImage Processing Pipeline
    
    /// Process image through the full pipeline: manual adjustments → film simulation → background removal → crop → rotate
    func processImage(url: URL, adjustments: ImageAdjustments) -> NSImage? {
        guard let ciImage = CIImage(contentsOf: url)?.oriented(forExifOrientation: getExifOrientation(url: url)) else { return nil }
        
        var image = ciImage
        
        // Step 1: Apply manual adjustments first
        image = applyManualAdjustments(to: image, adjustments: adjustments)
        
        // Step 2: Apply film simulation on top
        image = applyFilmSimulation(to: image, simulation: adjustments.filmSimulation)
        
        // Step 3: Background removal (before crop/rotate so mask aligns with original geometry)
        if adjustments.backgroundRemoved {
            if let masked = removeBackground(from: image) {
                image = masked
            }
        }
        
        // Step 4: Apply rotation
        image = applyRotation(to: image, steps: adjustments.rotationSteps, freeAngle: adjustments.rotationAngle)
        
        // Step 5: Apply crop
        image = applyCrop(to: image, normalizedRect: adjustments.cropRect)
        
        // Final: Render CIImage → CGImage → NSImage
        let outputExtent = image.extent
        guard let cgImage = ciContext.createCGImage(image, from: outputExtent) else { return nil }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    // MARK: - Background Removal (Vision Framework)
    
    private func removeBackground(from image: CIImage) -> CIImage? {
        if #available(macOS 14.0, *) {
            return removeBackgroundModern(from: image)
        } else {
            // Fallback: use VNGeneratePersonSegmentationRequest on macOS 13
            return removeBackgroundLegacy(from: image)
        }
    }
    
    @available(macOS 14.0, *)
    private func removeBackgroundModern(from image: CIImage) -> CIImage? {
        let extent = image.extent
        guard let cgImage = ciContext.createCGImage(image, from: extent) else { return nil }
        
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Background removal failed: \(error)")
            return nil
        }
        
        guard let result = request.results?.first else { return nil }
        
        do {
            let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
            let maskCIImage = CIImage(cvPixelBuffer: maskPixelBuffer)
            
            // Use blend with mask: original image + mask + transparent background
            guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return nil }
            blendFilter.setValue(image, forKey: kCIInputImageKey)
            blendFilter.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
            blendFilter.setValue(maskCIImage.transformed(by: CGAffineTransform(
                scaleX: extent.width / maskCIImage.extent.width,
                y: extent.height / maskCIImage.extent.height
            )), forKey: kCIInputMaskImageKey)
            
            return blendFilter.outputImage
        } catch {
            print("Mask generation failed: \(error)")
            return nil
        }
    }
    
    private func removeBackgroundLegacy(from image: CIImage) -> CIImage? {
        let extent = image.extent
        guard let cgImage = ciContext.createCGImage(image, from: extent) else { return nil }
        
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Person segmentation failed: \(error)")
            return nil
        }
        
        guard let result = request.results?.first,
              let maskBuffer = result.pixelBuffer as CVPixelBuffer? else { return nil }
        
        let maskCIImage = CIImage(cvPixelBuffer: maskBuffer)
        
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else { return nil }
        blendFilter.setValue(image, forKey: kCIInputImageKey)
        blendFilter.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(maskCIImage.transformed(by: CGAffineTransform(
            scaleX: extent.width / maskCIImage.extent.width,
            y: extent.height / maskCIImage.extent.height
        )), forKey: kCIInputMaskImageKey)
        
        return blendFilter.outputImage
    }
    
    // MARK: - Manual Adjustments (Exposure, Contrast, Saturation)
    
    private func applyManualAdjustments(to image: CIImage, adjustments: ImageAdjustments) -> CIImage {
        var result = image
        
        if adjustments.exposure != 0 {
            if let filter = CIFilter(name: "CIExposureAdjust") {
                filter.setValue(result, forKey: kCIInputImageKey)
                filter.setValue(adjustments.exposure * 2.0, forKey: kCIInputEVKey)
                if let output = filter.outputImage { result = output }
            }
        }
        
        if adjustments.contrast != 1.0 || adjustments.saturation != 1.0 {
            if let filter = CIFilter(name: "CIColorControls") {
                filter.setValue(result, forKey: kCIInputImageKey)
                filter.setValue(adjustments.saturation, forKey: kCIInputSaturationKey)
                filter.setValue(adjustments.contrast, forKey: kCIInputContrastKey)
                if let output = filter.outputImage { result = output }
            }
        }
        
        return result
    }
    
    // MARK: - Film Simulation Pipelines
    
    private func applyFilmSimulation(to image: CIImage, simulation: FilmSimulation) -> CIImage {
        switch simulation {
        case .none:
            return image
        case .provia:
            return applyProvia(to: image)
        case .velvia:
            return applyVelvia(to: image)
        case .classicChrome:
            return applyClassicChrome(to: image)
        case .astia:
            return applyAstia(to: image)
        case .eterna:
            return applyEterna(to: image)
        case .acros:
            return applyAcros(to: image)
        case .acrosRedFilter:
            return applyAcrosRedFilter(to: image)
        case .acrosYellowFilter:
            return applyAcrosYellowFilter(to: image)
        case .acrosGreenFilter:
            return applyAcrosGreenFilter(to: image)
        case .nostalgicNeg:
            return applyNostalgicNeg(to: image)
        case .proNegHi:
            return applyProNegHi(to: image)
        case .proNegStd:
            return applyProNegStd(to: image)
        case .classicNeg:
            return applyClassicNeg(to: image)
        case .bleachBypass:
            return applyBleachBypass(to: image)
        case .sepia:
            return applySepia(to: image)
        }
    }
    
    // Provia / Standard: Slight contrast boost (1.05), neutral saturation
    private func applyProvia(to image: CIImage) -> CIImage {
        var result = image
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(1.05, forKey: kCIInputContrastKey)
            filter.setValue(1.0, forKey: kCIInputSaturationKey)
            if let output = filter.outputImage { result = output }
        }
        return result
    }
    
    // Velvia: High saturation (1.6), lifted blacks, punchy contrast (1.2)
    private func applyVelvia(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(1.6, forKey: kCIInputSaturationKey)
            filter.setValue(1.2, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { result = output }
        }
        
        if let filter = CIFilter(name: "CIColorMatrix") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            filter.setValue(CIVector(x: 0.03, y: 0.03, z: 0.03, w: 0), forKey: "inputBiasVector")
            if let output = filter.outputImage { result = output }
        }
        
        return result
    }
    
    // Classic Chrome: Desaturated (0.7), cool shadows (blue channel shift), faded highlights
    private func applyClassicChrome(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.7, forKey: kCIInputSaturationKey)
            filter.setValue(1.0, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { result = output }
        }
        
        if let filter = CIFilter(name: "CIColorMatrix") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 1.05, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            filter.setValue(CIVector(x: -0.02, y: -0.01, z: 0.02, w: 0), forKey: "inputBiasVector")
            if let output = filter.outputImage { result = output }
        }
        
        return result
    }
    
    // Astia / Soft: Low contrast (0.9), warm skin tones (~150K warm shift), subtle saturation boost
    private func applyAstia(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.9, forKey: kCIInputContrastKey)
            filter.setValue(1.1, forKey: kCIInputSaturationKey)
            if let output = filter.outputImage { result = output }
        }
        
        if let filter = CIFilter(name: "CITemperatureAndTint") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 6650, y: 0), forKey: "inputNeutral")
            filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")
            if let output = filter.outputImage { result = output }
        }
        
        return result
    }
    
    // Eterna / Cinema: Very low saturation (0.6), flat contrast (0.85), lifted blacks
    private func applyEterna(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.6, forKey: kCIInputSaturationKey)
            filter.setValue(0.85, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { result = output }
        }
        
        if let filter = CIFilter(name: "CIExposureAdjust") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.15, forKey: kCIInputEVKey)
            if let output = filter.outputImage { result = output }
        }
        
        return result
    }
    
    // Acros: Grayscale (saturation 0), boost contrast (1.15), slight grain
    private func applyAcros(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.0, forKey: kCIInputSaturationKey)
            filter.setValue(1.15, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { result = output }
        }
        
        result = addGrain(to: result, intensity: 0.04)
        return result
    }
    
    // Acros + Red Filter: Boost red channel before grayscale conversion
    private func applyAcrosRedFilter(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CIColorMatrix") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 1.5, y: 0, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 0.7, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0.7, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")
            if let output = filter.outputImage { result = output }
        }
        
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.0, forKey: kCIInputSaturationKey)
            filter.setValue(1.15, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { result = output }
        }
        
        result = addGrain(to: result, intensity: 0.04)
        return result
    }
    
    // Acros + Yellow Filter: Boost red+green (yellow) before grayscale
    private func applyAcrosYellowFilter(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CIColorMatrix") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 1.3, y: 0, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 1.3, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0.5, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")
            if let output = filter.outputImage { result = output }
        }
        
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.0, forKey: kCIInputSaturationKey)
            filter.setValue(1.15, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { result = output }
        }
        
        result = addGrain(to: result, intensity: 0.04)
        return result
    }
    
    // Acros + Green Filter: Boost green channel before grayscale
    private func applyAcrosGreenFilter(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CIColorMatrix") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 0.7, y: 0, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 1.5, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0.7, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")
            if let output = filter.outputImage { result = output }
        }
        
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.0, forKey: kCIInputSaturationKey)
            filter.setValue(1.15, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { result = output }
        }
        
        result = addGrain(to: result, intensity: 0.04)
        return result
    }
    
    // Nostalgic Neg: Faded look — lift blacks, desaturate slightly (0.8), warm cast
    private func applyNostalgicNeg(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.8, forKey: kCIInputSaturationKey)
            filter.setValue(0.95, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { result = output }
        }
        
        if let filter = CIFilter(name: "CIColorMatrix") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            filter.setValue(CIVector(x: 0.07, y: 0.05, z: 0.03, w: 0), forKey: "inputBiasVector")
            if let output = filter.outputImage { result = output }
        }
        
        return result
    }
    
    // Pro Neg Hi: High contrast portrait look, slightly desaturated, warm midtones
    private func applyProNegHi(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.85, forKey: kCIInputSaturationKey)
            filter.setValue(1.15, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { result = output }
        }
        
        // Warm midtones
        if let filter = CIFilter(name: "CITemperatureAndTint") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 6600, y: 0), forKey: "inputNeutral")
            filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputTargetNeutral")
            if let output = filter.outputImage { result = output }
        }
        
        return result
    }
    
    // Pro Neg Std: Smooth tones, low contrast, slightly muted colors
    private func applyProNegStd(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.75, forKey: kCIInputSaturationKey)
            filter.setValue(0.9, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { result = output }
        }
        
        // Slight green-yellow shift for neutral skin tones
        if let filter = CIFilter(name: "CIColorMatrix") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            filter.setValue(CIVector(x: 0.01, y: 0.02, z: -0.01, w: 0), forKey: "inputBiasVector")
            if let output = filter.outputImage { result = output }
        }
        
        return result
    }
    
    // Classic Neg: Bold colors with shifted hues — warm shadows, cool highlights, high contrast
    private func applyClassicNeg(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(1.1, forKey: kCIInputSaturationKey)
            filter.setValue(1.1, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { result = output }
        }
        
        // Warm shadows, cool highlights — shift via color matrix
        if let filter = CIFilter(name: "CIColorMatrix") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 1.05, y: 0, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 0.98, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0.92, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            filter.setValue(CIVector(x: 0.03, y: 0.01, z: -0.02, w: 0), forKey: "inputBiasVector")
            if let output = filter.outputImage { result = output }
        }
        
        return result
    }
    
    // Bleach Bypass: Desaturated, high contrast, metallic look
    private func applyBleachBypass(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.5, forKey: kCIInputSaturationKey)
            filter.setValue(1.35, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { result = output }
        }
        
        // Slight cool cast
        if let filter = CIFilter(name: "CIColorMatrix") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 1.03, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
            filter.setValue(CIVector(x: -0.01, y: -0.01, z: 0.01, w: 0), forKey: "inputBiasVector")
            if let output = filter.outputImage { result = output }
        }
        
        return result
    }
    
    // Sepia: Classic warm brown tones
    private func applySepia(to image: CIImage) -> CIImage {
        var result = image
        
        if let filter = CIFilter(name: "CISepiaTone") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(0.7, forKey: kCIInputIntensityKey)
            if let output = filter.outputImage { result = output }
        }
        
        // Boost contrast slightly for richer sepia
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(result, forKey: kCIInputImageKey)
            filter.setValue(1.05, forKey: kCIInputContrastKey)
            if let output = filter.outputImage { result = output }
        }
        
        return result
    }
    
    // MARK: - Grain Helper
    
    private func addGrain(to image: CIImage, intensity: CGFloat) -> CIImage {
        guard let noiseFilter = CIFilter(name: "CIRandomGenerator"),
              let noiseImage = noiseFilter.outputImage else {
            return image
        }
        
        let croppedNoise = noiseImage.cropped(to: image.extent)
        
        guard let colorControls = CIFilter(name: "CIColorControls") else { return image }
        colorControls.setValue(croppedNoise, forKey: kCIInputImageKey)
        colorControls.setValue(0.0, forKey: kCIInputSaturationKey)
        colorControls.setValue(0.5, forKey: kCIInputBrightnessKey)
        
        guard let grayNoise = colorControls.outputImage else { return image }
        
        guard let blendFilter = CIFilter(name: "CISourceOverCompositing") else { return image }
        
        guard let alphaFilter = CIFilter(name: "CIColorMatrix") else { return image }
        alphaFilter.setValue(grayNoise, forKey: kCIInputImageKey)
        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: intensity), forKey: "inputAVector")
        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBiasVector")
        
        guard let transparentNoise = alphaFilter.outputImage else { return image }
        
        blendFilter.setValue(transparentNoise, forKey: kCIInputImageKey)
        blendFilter.setValue(image, forKey: kCIInputBackgroundImageKey)
        
        return blendFilter.outputImage ?? image
    }
    
    // MARK: - Rotation
    
    private func applyRotation(to image: CIImage, steps: Int, freeAngle: Double) -> CIImage {
        var result = image
        
        if steps > 0 {
            for _ in 0..<(steps % 4) {
                let transform = CGAffineTransform(translationX: result.extent.height, y: 0)
                    .rotated(by: .pi / 2)
                result = result.transformed(by: transform)
            }
        }
        
        if freeAngle != 0 {
            let radians = freeAngle * .pi / 180.0
            let center = CGPoint(x: result.extent.midX, y: result.extent.midY)
            
            let transform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: CGFloat(radians))
                .translatedBy(x: -center.x, y: -center.y)
            
            result = result.transformed(by: transform)
        }
        
        return result
    }
    
    // MARK: - Crop
    
    private func applyCrop(to image: CIImage, normalizedRect: CGRect) -> CIImage {
        if normalizedRect == CGRect(x: 0, y: 0, width: 1, height: 1) {
            return image
        }
        
        let extent = image.extent
        let pixelRect = CGRect(
            x: extent.origin.x + normalizedRect.origin.x * extent.width,
            y: extent.origin.y + normalizedRect.origin.y * extent.height,
            width: normalizedRect.width * extent.width,
            height: normalizedRect.height * extent.height
        )
        
        return image.cropped(to: pixelRect)
    }
    
    // MARK: - Save / Export
    
    func saveProcessedImage(url sourceURL: URL, adjustments: ImageAdjustments, to destinationURL: URL, format: ExportFormat, jpegQuality: Double) {
        guard let ciImage = CIImage(contentsOf: sourceURL) else { return }
        
        var image = ciImage
        
        image = applyManualAdjustments(to: image, adjustments: adjustments)
        image = applyFilmSimulation(to: image, simulation: adjustments.filmSimulation)
        
        if adjustments.backgroundRemoved {
            if let masked = removeBackground(from: image) {
                image = masked
            }
        }
        
        image = applyRotation(to: image, steps: adjustments.rotationSteps, freeAngle: adjustments.rotationAngle)
        image = applyCrop(to: image, normalizedRect: adjustments.cropRect)
        
        let outputExtent = image.extent
        guard let cgImage = ciContext.createCGImage(image, from: outputExtent) else { return }
        
        let utType: UTType
        switch format {
        case .jpeg: utType = .jpeg
        case .png: utType = .png
        case .tiff: utType = .tiff
        }
        
        let sourceRef = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)
        let originalProperties = sourceRef.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [String: Any] }
        
        let tempURL = destinationURL.appendingPathExtension("tmp_export")
        guard let destination = CGImageDestinationCreateWithURL(tempURL as CFURL, utType.identifier as CFString, 1, nil) else { return }
        
        var imageProperties: [String: Any] = originalProperties ?? [:]
        
        imageProperties.removeValue(forKey: kCGImagePropertyOrientation as String)
        if var tiffDict = imageProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiffDict.removeValue(forKey: kCGImagePropertyTIFFOrientation as String)
            imageProperties[kCGImagePropertyTIFFDictionary as String] = tiffDict
        }
        
        if format == .jpeg {
            imageProperties[kCGImageDestinationLossyCompressionQuality as String] = jpegQuality
        }
        
        CGImageDestinationAddImage(destination, cgImage, imageProperties as CFDictionary)
        
        if CGImageDestinationFinalize(destination) {
            do {
                if destinationURL == sourceURL {
                    _ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: tempURL)
                } else {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                }
            } catch {
                print("Failed to save processed image: \(error)")
                try? FileManager.default.removeItem(at: tempURL)
            }
        }
        
        cache.removeObject(forKey: sourceURL.path as NSString)
    }
    
    func saveEditedImage(url: URL, adjustments: ImageAdjustments) {
        saveProcessedImage(url: url, adjustments: adjustments, to: url, format: .jpeg, jpegQuality: 0.92)
    }
    
    // Helper to get orientation from ImageSource
    private func getExifOrientation(url: URL) -> Int32 {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return 1 }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        return (properties?[kCGImagePropertyOrientation as String] as? Int32) ?? 1
    }
}
