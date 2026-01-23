// Sources/SquishPDF/Compression/NativeEngine/ImageDownsampler.swift
import Foundation
import CoreGraphics
import CoreImage
import ImageIO

/// Downsamples and recompresses images
class ImageDownsampler {
    private let context: CIContext

    init() {
        self.context = CIContext(options: [.useSoftwareRenderer: false])
    }

    /// Downsample an image to target DPI and compress as JPEG
    /// - Parameters:
    ///   - image: Source CGImage
    ///   - currentDPI: Estimated current DPI of the image
    ///   - targetDPI: Target DPI after downsampling
    ///   - jpegQuality: JPEG quality (0.0 to 1.0)
    /// - Returns: JPEG data for the downsampled image
    func downsample(
        image: CGImage,
        currentDPI: Int,
        targetDPI: Int,
        jpegQuality: Double
    ) -> Data? {
        // Calculate scale factor
        let scale = min(1.0, Double(targetDPI) / Double(currentDPI))

        // If scale is close to 1.0, just recompress without scaling
        if scale > 0.95 {
            return compressAsJPEG(image: image, quality: jpegQuality)
        }

        // Calculate new dimensions
        let newWidth = Int(Double(image.width) * scale)
        let newHeight = Int(Double(image.height) * scale)

        guard newWidth > 0, newHeight > 0 else {
            return nil
        }

        // Use Core Image for high-quality downsampling
        let ciImage = CIImage(cgImage: image)

        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = ciImage.transformed(by: transform)

        // Apply Lanczos resampling for better quality
        guard let filter = CIFilter(name: "CILanczosScaleTransform") else {
            // Fallback: use the basic scaled image
            return renderAndCompress(ciImage: scaledImage, quality: jpegQuality)
        }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(scale, forKey: kCIInputScaleKey)
        filter.setValue(1.0, forKey: kCIInputAspectRatioKey)

        guard let outputImage = filter.outputImage else {
            return renderAndCompress(ciImage: scaledImage, quality: jpegQuality)
        }

        return renderAndCompress(ciImage: outputImage, quality: jpegQuality)
    }

    /// Compress a CGImage as JPEG without resizing
    func compressAsJPEG(image: CGImage, quality: Double) -> Data? {
        let ciImage = CIImage(cgImage: image)
        return renderAndCompress(ciImage: ciImage, quality: quality)
    }

    /// Render CIImage and compress to JPEG data
    private func renderAndCompress(ciImage: CIImage, quality: Double) -> Data? {
        let colorSpace = ciImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        return context.jpegRepresentation(
            of: ciImage,
            colorSpace: colorSpace,
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: quality]
        )
    }

    /// Estimate the DPI of an image given its pixel dimensions and display size in inches
    static func estimateDPI(pixelWidth: Int, pixelHeight: Int, displayWidthInches: Double, displayHeightInches: Double) -> Int {
        let dpiFromWidth = Double(pixelWidth) / displayWidthInches
        let dpiFromHeight = Double(pixelHeight) / displayHeightInches
        return Int(max(dpiFromWidth, dpiFromHeight))
    }
}
