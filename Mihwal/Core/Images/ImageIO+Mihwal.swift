import CoreGraphics
import Foundation
import ImageIO

/// Size and metadata of an image, with width/height as the user sees it (EXIF rotation applied).
struct ImageInfo {
    let width: Int
    let height: Int
    let hasAlpha: Bool
    let properties: [String: Any]

    var longestSide: Int { max(width, height) }
}

enum ImageReader {
    static func open(_ file: ImportedFile) throws -> (source: CGImageSource, info: ImageInfo) {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(file.url as CFURL, options),
              CGImageSourceGetCount(source) > 0,
              let info = info(of: source) else {
            throw ToolError.corruptedFile(fileName: file.name)
        }
        return (source, info)
    }

    static func info(of source: CGImageSource) -> ImageInfo? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int,
              width > 0, height > 0 else { return nil }
        // EXIF orientations 5–8 are sideways: the displayed width is the stored height.
        let orientation = properties[kCGImagePropertyOrientation as String] as? Int ?? 1
        let isSideways = (5...8).contains(orientation)
        return ImageInfo(width: isSideways ? height : width,
                         height: isSideways ? width : height,
                         hasAlpha: properties[kCGImagePropertyHasAlpha as String] as? Bool ?? false,
                         properties: properties)
    }

    /// Width × height as the user sees it, read from the file header only (fast).
    static func pixelSize(at url: URL) -> (width: Int, height: Int)? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options), let info = info(of: source) else {
            return nil
        }
        return (info.width, info.height)
    }

    /// Decodes the image upright (EXIF orientation baked into the pixels).
    /// `maxPixelSize` scales it down; nil keeps full resolution. Never scales up.
    static func uprightImage(from source: CGImageSource, info: ImageInfo, maxPixelSize: Int? = nil) -> CGImage? {
        let size = min(maxPixelSize ?? info.longestSide, info.longestSide)
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, size),
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}

enum ImageMetadata {
    /// Metadata to write with a processed image. Only standard dictionaries are kept
    /// (EXIF, TIFF, IPTC, GPS, DPI); orientation is set to "up" because the pixels are
    /// already upright; location is removed unless the user chose to keep it.
    /// The dates become `date` (now): the result is a new photo, so Photos lists it
    /// with today's pictures instead of next to the original.
    static func prepared(_ source: [String: Any], removeLocation: Bool, date: Date = Date()) -> [String: Any] {
        var result: [String: Any] = [:]
        let kept = [kCGImagePropertyExifDictionary, kCGImagePropertyTIFFDictionary, kCGImagePropertyIPTCDictionary,
                    kCGImagePropertyGPSDictionary, kCGImagePropertyDPIWidth, kCGImagePropertyDPIHeight]
        for key in kept.map({ $0 as String }) {
            result[key] = source[key]
        }
        if removeLocation {
            result[kCGImagePropertyGPSDictionary as String] = nil
        }
        result[kCGImagePropertyOrientation as String] = 1
        let stamp = exifDate(date)
        var exif = result[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
        exif[kCGImagePropertyExifPixelXDimension as String] = nil
        exif[kCGImagePropertyExifPixelYDimension as String] = nil
        exif[kCGImagePropertyExifDateTimeOriginal as String] = stamp
        exif[kCGImagePropertyExifDateTimeDigitized as String] = stamp
        // Old time-zone offsets and sub-seconds would contradict the new dates.
        for key in [kCGImagePropertyExifOffsetTime, kCGImagePropertyExifOffsetTimeOriginal,
                    kCGImagePropertyExifOffsetTimeDigitized, kCGImagePropertyExifSubsecTime,
                    kCGImagePropertyExifSubsecTimeOriginal, kCGImagePropertyExifSubsecTimeDigitized] {
            exif[key as String] = nil
        }
        result[kCGImagePropertyExifDictionary as String] = exif
        var tiff = result[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
        tiff[kCGImagePropertyTIFFOrientation as String] = 1
        tiff[kCGImagePropertyTIFFDateTime as String] = stamp
        result[kCGImagePropertyTIFFDictionary as String] = tiff
        return result
    }

    /// EXIF date format: "2026:10:30 18:45:00" in local time.
    static func exifDate(_ date: Date) -> String {
        exifFormatter.string(from: date)
    }

    private static let exifFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()
}

enum ImageWriter {
    static func write(_ image: CGImage, to url: URL, format: ImageFormat, quality: Double,
                      sourceProperties: [String: Any], removeLocation: Bool) throws {
        guard format.canEncode else {
            throw ToolError.unsupportedFormat(fileName: url.lastPathComponent)
        }
        // JPEG has no transparency: flatten onto white instead of getting black corners.
        var finalImage = image
        if format == .jpeg, image.hasAlpha, let flat = ImageCanvas.flattened(image) {
            finalImage = flat
        }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, format.utType.identifier as CFString, 1, nil) else {
            throw ToolError.writeFailed
        }
        var properties = ImageMetadata.prepared(sourceProperties, removeLocation: removeLocation)
        if format.isLossy {
            properties[kCGImageDestinationLossyCompressionQuality as String] = min(1, max(0, quality))
        }
        CGImageDestinationAddImage(destination, finalImage, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ToolError.writeFailed
        }
    }
}

enum ImageCanvas {
    /// An 8-bit drawing context, in the image's own RGB color space when possible
    /// (keeps Display P3 photos vivid), otherwise sRGB.
    static func context(width: Int, height: Int, like image: CGImage?, opaque: Bool) -> CGContext? {
        let preferred = image?.colorSpace.flatMap { $0.model == .rgb ? $0 : nil }
        let spaces = [preferred, CGColorSpace(name: CGColorSpace.sRGB)].compactMap { $0 }
        let bitmapInfo = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
        for space in spaces {
            if let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                       bytesPerRow: 0, space: space, bitmapInfo: bitmapInfo) {
                context.interpolationQuality = .high
                return context
            }
        }
        return nil
    }

    static func flattened(_ image: CGImage) -> CGImage? {
        guard let context = context(width: image.width, height: image.height, like: image, opaque: true) else { return nil }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(rect)
        context.draw(image, in: rect)
        return context.makeImage()
    }
}

enum ImageTransform {
    /// Flips (in the image's own axes), then rotates clockwise by quarter turns.
    /// The same order as the preview: scaleEffect, then rotationEffect.
    static func apply(_ image: CGImage, quarterTurns: Int, flipHorizontal: Bool, flipVertical: Bool) -> CGImage? {
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns != 0 || flipHorizontal || flipVertical else { return image }

        let isSideways = turns % 2 == 1
        let newWidth = isSideways ? image.height : image.width
        let newHeight = isSideways ? image.width : image.height
        guard let context = ImageCanvas.context(width: newWidth, height: newHeight, like: image,
                                                opaque: !image.hasAlpha) else { return nil }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        context.translateBy(x: CGFloat(newWidth) / 2, y: CGFloat(newHeight) / 2)
        // Core Graphics' y axis points up, so a clockwise turn is a negative angle.
        context.rotate(by: -CGFloat(turns) * .pi / 2)
        context.scaleBy(x: flipHorizontal ? -1 : 1, y: flipVertical ? -1 : 1)
        context.draw(image, in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height))
        return context.makeImage()
    }
}

extension CGImage {
    var hasAlpha: Bool {
        switch alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        default:
            return true
        }
    }
}

/// Runs an image tool over every file: one image at a time, inside an autorelease pool
/// (so a batch of 48 MP photos never piles up in memory), with progress and cancel.
enum ImageBatch {
    static func run(_ input: ToolInput,
                    progress: @escaping @Sendable (Double) -> Void,
                    _ process: (ImportedFile, URL) throws -> URL) throws -> ToolOutput {
        guard !input.files.isEmpty else { throw ToolError.noInput }
        let totalBytes = input.files.reduce(0) { $0 + $1.byteCount }
        try StorageGuard.ensureSpace(for: totalBytes * 2)

        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            var urls: [URL] = []
            for (index, file) in input.files.enumerated() {
                try Task.checkCancellation()
                let url = try autoreleasepool {
                    try process(file, folder)
                }
                urls.append(url)
                progress(Double(index + 1) / Double(input.files.count))
            }
            return ToolOutput(directory: folder, files: urls)
        }
    }

    static func outputURL(for file: ImportedFile, in folder: URL, suffix: String, format: ImageFormat) -> URL {
        FileStore.outputURL(in: folder, baseName: file.baseName, suffix: suffix, pathExtension: format.fileExtension)
    }
}
