// Sources/SquishPDF/Compression/NativeEngine/PDFImageExtractor.swift
import Foundation
import CoreGraphics
import ImageIO

/// Information about an extracted image
struct ExtractedImage {
    let name: String           // XObject name (e.g., "Im0")
    let pageIndex: Int         // Which page references this image
    let cgImage: CGImage       // The extracted image
    let originalWidth: Int
    let originalHeight: Int
    let bitsPerComponent: Int
    let colorSpaceName: String
}

/// Extracts images from PDF XObjects
class PDFImageExtractor {

    /// Extract all images from a PDF document
    func extractImages(from document: CGPDFDocument) -> [ExtractedImage] {
        var images: [ExtractedImage] = []

        for pageIndex in 1...document.numberOfPages {
            guard let page = document.page(at: pageIndex) else { continue }

            let pageImages = extractImages(from: page, pageIndex: pageIndex)
            images.append(contentsOf: pageImages)
        }

        return images
    }

    /// Extract images from a single page
    private func extractImages(from page: CGPDFPage, pageIndex: Int) -> [ExtractedImage] {
        var images: [ExtractedImage] = []

        guard let pageDictionary = page.dictionary else { return images }

        // Get Resources dictionary
        var resourcesDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(pageDictionary, "Resources", &resourcesDict),
              let resources = resourcesDict else {
            return images
        }

        // Get XObject dictionary
        var xObjectDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(resources, "XObject", &xObjectDict),
              let xObjects = xObjectDict else {
            return images
        }

        // Iterate through XObjects
        CGPDFDictionaryApplyBlock(xObjects) { (key, value, _) -> Bool in
            let name = String(cString: key)

            // Check if this is an image
            var stream: CGPDFStreamRef?
            guard CGPDFObjectGetValue(value, .stream, &stream),
                  let imageStream = stream else {
                return true  // Continue iteration
            }

            guard let streamDict = CGPDFStreamGetDictionary(imageStream) else {
                return true
            }

            // Verify it's an Image subtype
            var subtypeName: UnsafePointer<Int8>?
            guard CGPDFDictionaryGetName(streamDict, "Subtype", &subtypeName),
                  let subtype = subtypeName,
                  String(cString: subtype) == "Image" else {
                return true
            }

            // Extract image properties
            var width: CGPDFInteger = 0
            var height: CGPDFInteger = 0
            var bitsPerComponent: CGPDFInteger = 8

            CGPDFDictionaryGetInteger(streamDict, "Width", &width)
            CGPDFDictionaryGetInteger(streamDict, "Height", &height)
            CGPDFDictionaryGetInteger(streamDict, "BitsPerComponent", &bitsPerComponent)

            // Get color space name
            var colorSpaceName = "Unknown"
            var csName: UnsafePointer<Int8>?
            if CGPDFDictionaryGetName(streamDict, "ColorSpace", &csName),
               let csNamePtr = csName {
                colorSpaceName = String(cString: csNamePtr)
            }

            // Try to extract the image data and create CGImage
            if let cgImage = self.createCGImage(from: imageStream, dict: streamDict) {
                let extracted = ExtractedImage(
                    name: name,
                    pageIndex: pageIndex,
                    cgImage: cgImage,
                    originalWidth: Int(width),
                    originalHeight: Int(height),
                    bitsPerComponent: Int(bitsPerComponent),
                    colorSpaceName: colorSpaceName
                )
                images.append(extracted)
            }

            return true  // Continue iteration
        }

        return images
    }

    /// Create a CGImage from a PDF image stream
    private func createCGImage(from stream: CGPDFStreamRef, dict: CGPDFDictionaryRef) -> CGImage? {
        var format: CGPDFDataFormat = .raw
        guard let data = CGPDFStreamCopyData(stream, &format) else {
            return nil
        }

        var width: CGPDFInteger = 0
        var height: CGPDFInteger = 0
        var bitsPerComponent: CGPDFInteger = 8

        CGPDFDictionaryGetInteger(dict, "Width", &width)
        CGPDFDictionaryGetInteger(dict, "Height", &height)
        CGPDFDictionaryGetInteger(dict, "BitsPerComponent", &bitsPerComponent)

        // Handle different compression formats
        switch format {
        case .JPEG, .JPEG2000:
            // Already compressed image data - decode via ImageIO
            guard let dataProvider = CGDataProvider(data: data),
                  let image = CGImage(jpegDataProviderSource: dataProvider,
                                      decode: nil,
                                      shouldInterpolate: true,
                                      intent: .defaultIntent) else {
                return nil
            }
            return image

        case .raw:
            // Raw image data - need to construct CGImage manually
            return createCGImageFromRawData(
                data: data as Data,
                width: Int(width),
                height: Int(height),
                bitsPerComponent: Int(bitsPerComponent),
                dict: dict
            )
        @unknown default:
            return nil
        }
    }

    /// Create CGImage from raw (uncompressed or Flate-decoded) data
    private func createCGImageFromRawData(
        data: Data,
        width: Int,
        height: Int,
        bitsPerComponent: Int,
        dict: CGPDFDictionaryRef
    ) -> CGImage? {
        // Determine color space and components
        var componentsPerPixel = 3  // Default to RGB
        var colorSpace = CGColorSpaceCreateDeviceRGB()

        var csName: UnsafePointer<Int8>?
        if CGPDFDictionaryGetName(dict, "ColorSpace", &csName),
           let name = csName {
            let csString = String(cString: name)
            switch csString {
            case "DeviceGray":
                componentsPerPixel = 1
                colorSpace = CGColorSpaceCreateDeviceGray()
            case "DeviceCMYK":
                componentsPerPixel = 4
                colorSpace = CGColorSpaceCreateDeviceCMYK()
            default:
                break  // Keep RGB default
            }
        }

        let bitsPerPixel = bitsPerComponent * componentsPerPixel
        let bytesPerRow = (width * bitsPerPixel + 7) / 8

        guard let dataProvider = CGDataProvider(data: data as CFData) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bitsPerPixel,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}
