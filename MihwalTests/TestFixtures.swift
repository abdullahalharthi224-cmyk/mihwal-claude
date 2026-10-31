import ImageIO
import PDFKit
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import Mihwal

/// Builds small sample files on the fly, so the repo has no binary test fixtures.
enum TestFixtures {
    static func scratchDirectory() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("MihwalTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// A PDF whose pages have the given widths, so tests can tell pages apart by size.
    static func makePDF(pageWidths: [CGFloat], name: String = "sample.pdf") throws -> URL {
        let url = try scratchDirectory().appendingPathComponent(name)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 300))
        let data = renderer.pdfData { context in
            for (index, width) in pageWidths.enumerated() {
                context.beginPage(withBounds: CGRect(x: 0, y: 0, width: width, height: 300), pageInfo: [:])
                ("Page \(index + 1)" as NSString).draw(at: CGPoint(x: 10, y: 10), withAttributes: nil)
            }
        }
        try data.write(to: url)
        return url
    }

    static func makeEncryptedPDF(password: String) throws -> URL {
        let plain = try makePDF(pageWidths: [200, 250])
        let document = try XCTUnwrap(PDFDocument(url: plain))
        let url = plain.deletingLastPathComponent().appendingPathComponent("locked.pdf")
        let written = document.write(to: url, withOptions: [
            .userPasswordOption: password,
            .ownerPasswordOption: password,
        ])
        XCTAssertTrue(written)
        return url
    }

    /// A PDF that opens without a password but whose owner blocked copying and printing.
    static func makeRestrictedPDF(ownerPassword: String) throws -> URL {
        let url = try scratchDirectory().appendingPathComponent("restricted.pdf")
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextOwnerPassword as String: ownerPassword,
            kCGPDFContextAllowsCopying as String: false,
            kCGPDFContextAllowsPrinting as String: false,
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 300), format: format)
        try renderer.pdfData { context in
            context.beginPage()
            ("Restricted" as NSString).draw(at: CGPoint(x: 10, y: 10), withAttributes: nil)
        }.write(to: url)
        return url
    }

    /// Needs `open` to open, and `owner` to make changes (copying is blocked).
    static func makeLockedAndRestrictedPDF(open: String, owner: String) throws -> URL {
        let url = try scratchDirectory().appendingPathComponent("locked-restricted.pdf")
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextUserPassword as String: open,
            kCGPDFContextOwnerPassword as String: owner,
            kCGPDFContextAllowsCopying as String: false,
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 300), format: format)
        try renderer.pdfData { context in
            context.beginPage()
            ("Locked and restricted" as NSString).draw(at: CGPoint(x: 10, y: 10), withAttributes: nil)
        }.write(to: url)
        return url
    }

    /// A file from the repository's samples/ folder (the same files the owner downloads).
    static func sample(_ name: String) throws -> URL {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("samples/\(name)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing sample \(name)")
        return url
    }

    /// A PDF with personal document information.
    static func makePDFWithMetadata() throws -> URL {
        let url = try scratchDirectory().appendingPathComponent("with-metadata.pdf")
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Secret plan",
            kCGPDFContextAuthor as String: "Abdullah",
            kCGPDFContextSubject as String: "Private",
            kCGPDFContextKeywords as String: "hidden",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 300), format: format)
        try renderer.pdfData { context in
            context.beginPage()
            ("Hello" as NSString).draw(at: CGPoint(x: 10, y: 10), withAttributes: nil)
        }.write(to: url)
        return url
    }

    /// A page split in two colors (left red, right blue in page space), optionally rotated,
    /// to check that redrawing keeps what the user sees.
    static func makeColoredPDF(rotation: Int, name: String = "colored.pdf") throws -> URL {
        let plain = try scratchDirectory().appendingPathComponent("plain-\(name)")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 300))
        try renderer.pdfData { context in
            context.beginPage()
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 300))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 100, y: 0, width: 100, height: 300))
        }.write(to: plain)
        let document = try XCTUnwrap(PDFDocument(url: plain))
        document.page(at: 0)?.rotation = rotation
        let url = plain.deletingLastPathComponent().appendingPathComponent(name)
        XCTAssertTrue(document.write(to: url))
        return url
    }

    /// A "scanned" page: one big noisy image, which compresses well as JPEG.
    static func makeImageHeavyPDF() throws -> URL {
        let url = try scratchDirectory().appendingPathComponent("scan.pdf")
        let side = 900
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        var seed: UInt32 = 12345
        for i in stride(from: 0, to: bytes.count, by: 4) {
            seed = seed &* 1_103_515_245 &+ 12345
            let value = UInt8(truncatingIfNeeded: seed >> 16)
            bytes[i] = value
            bytes[i + 1] = value &+ UInt8(truncatingIfNeeded: i)
            bytes[i + 2] = 255 &- value
            bytes[i + 3] = 255
        }
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
        let image = try XCTUnwrap(CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
                                          bytesPerRow: side * 4, space: space,
                                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                          provider: provider, decode: nil, shouldInterpolate: false,
                                          intent: .defaultIntent))
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        try renderer.pdfData { context in
            context.beginPage()
            UIImage(cgImage: image).draw(in: CGRect(x: 0, y: 0, width: 612, height: 792))
        }.write(to: url)
        return url
    }

    static func makePNG(width: Int, height: Int, name: String = "image.png") throws -> URL {
        let url = try scratchDirectory().appendingPathComponent(name)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        try XCTUnwrap(image.pngData()).write(to: url)
        return url
    }

    static func makeGarbage(name: String) throws -> URL {
        let url = try scratchDirectory().appendingPathComponent(name)
        try Data("this is not a real file".utf8).write(to: url)
        return url
    }

    static func imported(_ url: URL) throws -> ImportedFile {
        try FileStore.importCopy(of: url, coordinated: false)
    }
}

extension XCTestCase {
    /// Polls until `condition` is true (async work such as importing or running a tool).
    @MainActor
    func waitUntil(timeout: TimeInterval = 10, _ condition: @escaping @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Timed out waiting for condition")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}


/// Image fixtures: a "split" image (left half red, right half blue) makes rotation,
/// flips and EXIF orientation checkable by looking at a few pixels.
enum ImageFixtures {
    static func splitCGImage(width: Int = 80, height: Int = 40) throws -> CGImage {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: 0, space: space,
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        return try XCTUnwrap(context.makeImage())
    }

    /// Writes an image with optional EXIF orientation and GPS location.
    static func write(_ image: CGImage, type: UTType, name: String,
                      orientation: Int = 1, withLocation: Bool = false, quality: Double = 0.95) throws -> URL {
        let url = try TestFixtures.scratchDirectory().appendingPathComponent(name)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        var properties: [String: Any] = [
            kCGImagePropertyOrientation as String: orientation,
            kCGImageDestinationLossyCompressionQuality as String: quality,
        ]
        if withLocation {
            properties[kCGImagePropertyGPSDictionary as String] = [
                kCGImagePropertyGPSLatitude as String: 24.7136,
                kCGImagePropertyGPSLatitudeRef as String: "N",
                kCGImagePropertyGPSLongitude as String: 46.6753,
                kCGImagePropertyGPSLongitudeRef as String: "E",
            ]
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    /// A photo-like gradient (compresses very differently as PNG and JPEG).
    static func gradientCGImage(width: Int = 600, height: Int = 400) throws -> CGImage {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: 0, space: space,
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        for x in stride(from: 0, to: width, by: 2) {
            for y in stride(from: 0, to: height, by: 2) {
                let r = CGFloat(x) / CGFloat(width)
                let g = CGFloat(y) / CGFloat(height)
                let b = CGFloat((x * 7 + y * 13) % 255) / 255
                context.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
                context.fill(CGRect(x: x, y: y, width: 2, height: 2))
            }
        }
        return try XCTUnwrap(context.makeImage())
    }

    /// The image as stored (no orientation applied) and its properties.
    static func read(_ url: URL) throws -> (image: CGImage, properties: [String: Any]) {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        return (image, properties)
    }

    /// Color at (x, y), with (0, 0) the top-left pixel.
    static func pixel(_ image: CGImage, x: Int, y: Int) throws -> (red: Int, green: Int, blue: Int) {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var bytes = [UInt8](repeating: 0, count: 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                          bytesPerRow: 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.translateBy(x: -CGFloat(x), y: -CGFloat(image.height - 1 - y))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(drawn)
        return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]))
    }

    static func isRed(_ p: (red: Int, green: Int, blue: Int)) -> Bool { p.red > 180 && p.blue < 90 }
    static func isBlue(_ p: (red: Int, green: Int, blue: Int)) -> Bool { p.blue > 180 && p.red < 90 }
}
