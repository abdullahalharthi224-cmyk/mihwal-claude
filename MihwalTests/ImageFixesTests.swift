import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Mihwal

/// Checks for three things seen on the iPhone: size really changes, rotation result
/// matches what was chosen (also for camera photos stored sideways), and saved photos
/// are dated now instead of with the original's date.
final class ImageFixesTests: XCTestCase {
    /// Like an iPhone camera photo: stored 400×200 sideways, EXIF says "turn clockwise".
    private func cameraLikePhoto(name: String) throws -> ImportedFile {
        let url = try ImageFixtures.write(try ImageFixtures.splitCGImage(width: 400, height: 200),
                                          type: .jpeg, name: name, orientation: 6)
        return try TestFixtures.imported(url)
    }

    // MARK: Size

    func testPixelSizeIsWhatTheUserSees() throws {
        let file = try cameraLikePhoto(name: "camera.jpg")
        let size = try XCTUnwrap(ImageReader.pixelSize(at: file.url))
        XCTAssertEqual([size.width, size.height], [200, 400], "Sideways photo is shown portrait")
    }

    func testResizeReallyChangesPixelsOfACameraPhoto() async throws {
        let file = try cameraLikePhoto(name: "resize.jpg")
        let output = try await ResizeImageEngine().run(input: ToolInput(files: [file]),
                                                       options: .init(mode: .percent(50))) { _ in }
        let url = try XCTUnwrap(output.files.first)
        let size = try XCTUnwrap(ImageReader.pixelSize(at: url))
        XCTAssertEqual([size.width, size.height], [100, 200])
        let stored = try ImageFixtures.read(url)
        XCTAssertEqual([stored.image.width, stored.image.height], [100, 200], "Pixels themselves are smaller")
        XCTAssertEqual(stored.properties[kCGImagePropertyOrientation as String] as? Int ?? 1, 1)
    }

    // MARK: Rotation

    func testRotateClockwiseOnACameraPhotoMatchesWhatIsShown() async throws {
        // Upright, the photo is portrait with red on top. Turned clockwise, the top goes
        // to the right: landscape, red on the right, blue on the left.
        let file = try cameraLikePhoto(name: "turn.jpg")
        let output = try await RotateImageEngine().run(input: ToolInput(files: [file]),
                                                       options: .init(quarterTurns: 1)) { _ in }
        let stored = try ImageFixtures.read(try XCTUnwrap(output.files.first))
        XCTAssertEqual(stored.properties[kCGImagePropertyOrientation as String] as? Int ?? 1, 1,
                       "Saved upright, so every app shows it the same way")
        XCTAssertEqual([stored.image.width, stored.image.height], [400, 200])
        XCTAssertTrue(ImageFixtures.isBlue(try ImageFixtures.pixel(stored.image, x: 60, y: 100)))
        XCTAssertTrue(ImageFixtures.isRed(try ImageFixtures.pixel(stored.image, x: 340, y: 100)))
    }

    func testPreviewAndSavedImageUseTheSameTransform() async throws {
        // The preview is ImageTransform on a smaller copy; the engine is ImageTransform on
        // the full image. Same colors in the same places, whatever the options.
        let file = try cameraLikePhoto(name: "same.jpg")
        let opened = try ImageReader.open(file)
        let small = try XCTUnwrap(ImageReader.uprightImage(from: opened.source, info: opened.info, maxPixelSize: 100))
        for options in [RotateImageEngine.Options(quarterTurns: 1),
                        RotateImageEngine.Options(quarterTurns: 3, flipHorizontal: true),
                        RotateImageEngine.Options(flipVertical: true)] {
            let preview = try XCTUnwrap(ImageTransform.apply(small, quarterTurns: options.quarterTurns,
                                                             flipHorizontal: options.flipHorizontal,
                                                             flipVertical: options.flipVertical))
            let output = try await RotateImageEngine().run(input: ToolInput(files: [file]), options: options) { _ in }
            let saved = try ImageFixtures.read(try XCTUnwrap(output.files.first)).image
            XCTAssertEqual(Double(preview.width) / Double(preview.height),
                           Double(saved.width) / Double(saved.height), accuracy: 0.05)
            for (fx, fy) in [(0.2, 0.2), (0.8, 0.8), (0.2, 0.8), (0.8, 0.2)] {
                let p = try ImageFixtures.pixel(preview, x: Int(Double(preview.width) * fx), y: Int(Double(preview.height) * fy))
                let s = try ImageFixtures.pixel(saved, x: Int(Double(saved.width) * fx), y: Int(Double(saved.height) * fy))
                XCTAssertEqual(ImageFixtures.isRed(p), ImageFixtures.isRed(s), "\(options) at \(fx),\(fy)")
            }
        }
    }

    // MARK: Dates

    func testMetadataDatesBecomeNow() {
        let source: [String: Any] = [
            kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: "2015:01:01 10:00:00",
                kCGImagePropertyExifOffsetTimeOriginal as String: "+03:00",
            ],
            kCGImagePropertyTIFFDictionary as String: [kCGImagePropertyTIFFDateTime as String: "2015:01:01 10:00:00"],
        ]
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let prepared = ImageMetadata.prepared(source, removeLocation: true, date: now)
        let exif = prepared[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = prepared[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let expected = ImageMetadata.exifDate(now)
        XCTAssertEqual(exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String, expected)
        XCTAssertEqual(exif?[kCGImagePropertyExifDateTimeDigitized as String] as? String, expected)
        XCTAssertNil(exif?[kCGImagePropertyExifOffsetTimeOriginal as String])
        XCTAssertEqual(tiff?[kCGImagePropertyTIFFDateTime as String] as? String, expected)
        XCTAssertTrue(expected.hasPrefix("2027:01:1"), "EXIF format yyyy:MM:dd, got \(expected)")
    }

    func testSavedImageIsDatedNowNotWithTheOriginalDate() async throws {
        let url = try TestFixtures.scratchDirectory().appendingPathComponent("old.jpg")
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try ImageFixtures.splitCGImage(), [
            kCGImagePropertyExifDictionary as String: [kCGImagePropertyExifDateTimeOriginal as String: "2015:01:01 10:00:00"],
        ] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let output = try await ConvertImageEngine().run(input: ToolInput(files: [try TestFixtures.imported(url)]),
                                                        options: .init(format: .jpeg)) { _ in }
        let properties = try ImageFixtures.read(try XCTUnwrap(output.files.first)).properties
        let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let date = try XCTUnwrap(exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String)
        XCTAssertFalse(date.hasPrefix("2015"))
        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        XCTAssertTrue(date.hasPrefix("\(year):"), "Expected this year's date, got \(date)")
    }
}
