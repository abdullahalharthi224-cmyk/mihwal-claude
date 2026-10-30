import CoreText
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Mihwal

final class ImageToolEngineTests: XCTestCase {
    private func imported(_ url: URL) throws -> ImportedFile {
        try TestFixtures.imported(url)
    }

    // MARK: Formats

    func testFormatsAndPreservingRules() {
        XCTAssertTrue(ImageFormat.jpeg.canEncode)
        XCTAssertTrue(ImageFormat.png.canEncode)
        XCTAssertEqual(ImageFormat.preserving(.png, hasAlpha: false), .png)
        XCTAssertEqual(ImageFormat.preserving(.jpeg, hasAlpha: false), .jpeg)
        XCTAssertEqual(ImageFormat.preserving(.webP, hasAlpha: true), .png, "WebP can't be written: keep transparency in PNG")
        XCTAssertEqual(ImageFormat.preserving(.webP, hasAlpha: false), .jpeg)
        XCTAssertFalse(ImageFormat.exportable.contains { $0.utType == .webP })
    }

    // MARK: Convert

    func testConvertBakesEXIFOrientationIntoPixels() async throws {
        // Stored 80×40 (red left, blue right) with orientation 6 = "turn 90° clockwise to view".
        // Viewed upright it is 40×80 with red on top.
        let source = try ImageFixtures.write(try ImageFixtures.splitCGImage(), type: .jpeg,
                                             name: "sideways.jpg", orientation: 6)
        let output = try await ConvertImageEngine().run(
            input: ToolInput(files: [try imported(source)]), options: .init(format: .png)) { _ in }

        let result = try ImageFixtures.read(try XCTUnwrap(output.files.first))
        XCTAssertEqual(result.image.width, 40)
        XCTAssertEqual(result.image.height, 80)
        XCTAssertEqual(result.properties[kCGImagePropertyOrientation as String] as? Int ?? 1, 1,
                       "Pixels are upright, so orientation must say 'up'")
        XCTAssertTrue(ImageFixtures.isRed(try ImageFixtures.pixel(result.image, x: 20, y: 10)))
        XCTAssertTrue(ImageFixtures.isBlue(try ImageFixtures.pixel(result.image, x: 20, y: 70)))
    }

    func testLocationIsRemovedByDefaultAndKeptWhenAsked() async throws {
        let source = try ImageFixtures.write(try ImageFixtures.splitCGImage(), type: .jpeg,
                                             name: "located.jpg", withLocation: true)
        let file = try imported(source)
        XCTAssertNotNil(try ImageFixtures.read(source).properties[kCGImagePropertyGPSDictionary as String],
                        "Fixture should carry a location")

        let stripped = try await ConvertImageEngine().run(input: ToolInput(files: [file]),
                                                          options: .init(format: .jpeg)) { _ in }
        XCTAssertNil(try ImageFixtures.read(try XCTUnwrap(stripped.files.first)).properties[kCGImagePropertyGPSDictionary as String])

        let kept = try await ConvertImageEngine().run(input: ToolInput(files: [file]),
                                                      options: .init(format: .jpeg, removeLocation: false)) { _ in }
        XCTAssertNotNil(try ImageFixtures.read(try XCTUnwrap(kept.files.first)).properties[kCGImagePropertyGPSDictionary as String])
    }

    func testTransparentPNGBecomesJPEGOnWhite() async throws {
        let png = try TestFixtures.makePNG(width: 20, height: 20, name: "icon.png")
        let output = try await ConvertImageEngine().run(input: ToolInput(files: [try imported(png)]),
                                                        options: .init(format: .jpeg)) { _ in }
        let url = try XCTUnwrap(output.files.first)
        XCTAssertEqual(url.pathExtension, "jpg")
        XCTAssertEqual(FileStore.contentType(of: url), .jpeg)
    }

    func testHEICOutputWhenTheDeviceCanEncodeIt() async throws {
        try XCTSkipUnless(ImageFormat.heic.canEncode, "No HEIC encoder on this simulator")
        let source = try ImageFixtures.write(try ImageFixtures.splitCGImage(), type: .png, name: "a.png")
        let output = try await ConvertImageEngine().run(input: ToolInput(files: [try imported(source)]),
                                                        options: .init(format: .heic)) { _ in }
        XCTAssertEqual(try XCTUnwrap(output.files.first).pathExtension, "heic")
    }

    func testDamagedImageIsReported() async throws {
        let file = try imported(try TestFixtures.makeGarbage(name: "broken.jpg"))
        do {
            _ = try await ConvertImageEngine().run(input: ToolInput(files: [file]), options: .init()) { _ in }
            XCTFail("Expected an error")
        } catch let error as ToolError {
            XCTAssertEqual(error, .corruptedFile(fileName: "broken.jpg"))
        }
    }

    // MARK: Compress

    func testCompressReportsBeforeAfterAndShrinks() async throws {
        let png = try ImageFixtures.write(try ImageFixtures.gradientCGImage(), type: .png, name: "photo.png")
        let file = try imported(png)
        let output = try await CompressImageEngine().run(input: ToolInput(files: [file]),
                                                         options: .init(quality: 0.5, format: .jpeg)) { _ in }
        XCTAssertEqual(output.inputBytes, file.byteCount)
        XCTAssertLessThan(output.outputBytes, file.byteCount)
        XCTAssertTrue(output.notes.isEmpty)
    }

    func testCompressNeverReturnsABiggerFile() async throws {
        // Already heavily compressed: re-encoding at top quality would grow it.
        let tiny = try ImageFixtures.write(try ImageFixtures.gradientCGImage(), type: .jpeg, name: "tiny.jpg", quality: 0.05)
        let file = try imported(tiny)
        let output = try await CompressImageEngine().run(input: ToolInput(files: [file]),
                                                         options: .init(quality: 1, format: .jpeg)) { _ in }
        XCTAssertLessThanOrEqual(output.outputBytes, file.byteCount)
        XCTAssertEqual(output.notes.count, 1, "The user is told the original was kept")
    }

    func testCompressCanLimitSize() async throws {
        let png = try ImageFixtures.write(try ImageFixtures.gradientCGImage(), type: .png, name: "big.png")
        let output = try await CompressImageEngine().run(input: ToolInput(files: [try imported(png)]),
                                                         options: .init(format: .jpeg, maxPixelSize: 300)) { _ in }
        let result = try ImageFixtures.read(try XCTUnwrap(output.files.first))
        XCTAssertEqual(max(result.image.width, result.image.height), 300)
    }

    // MARK: Resize

    func testResizeByPercentAndLongestSideWithoutUpscaling() async throws {
        let png = try ImageFixtures.write(try ImageFixtures.splitCGImage(width: 400, height: 200), type: .png, name: "r.png")
        let file = try imported(png)

        let half = try await ResizeImageEngine().run(input: ToolInput(files: [file]),
                                                     options: .init(mode: .percent(50))) { _ in }
        let halfImage = try ImageFixtures.read(try XCTUnwrap(half.files.first)).image
        XCTAssertEqual([halfImage.width, halfImage.height], [200, 100])

        let side = try await ResizeImageEngine().run(input: ToolInput(files: [file]),
                                                     options: .init(mode: .longestSide(100))) { _ in }
        let sideImage = try ImageFixtures.read(try XCTUnwrap(side.files.first)).image
        XCTAssertEqual([sideImage.width, sideImage.height], [100, 50])

        let bigger = try await ResizeImageEngine().run(input: ToolInput(files: [file]),
                                                       options: .init(mode: .longestSide(4000))) { _ in }
        let biggerImage = try ImageFixtures.read(try XCTUnwrap(bigger.files.first)).image
        XCTAssertEqual([biggerImage.width, biggerImage.height], [400, 200], "Never enlarged")
        XCTAssertEqual(bigger.notes.count, 1)
    }

    // MARK: Rotate / flip

    func testTransformRotatesClockwiseAndFlips() throws {
        let split = try ImageFixtures.splitCGImage() // red left, blue right

        let clockwise = try XCTUnwrap(ImageTransform.apply(split, quarterTurns: 1, flipHorizontal: false, flipVertical: false))
        XCTAssertEqual([clockwise.width, clockwise.height], [40, 80])
        XCTAssertTrue(ImageFixtures.isRed(try ImageFixtures.pixel(clockwise, x: 20, y: 10)), "Left side goes to the top")

        let counter = try XCTUnwrap(ImageTransform.apply(split, quarterTurns: -1, flipHorizontal: false, flipVertical: false))
        XCTAssertTrue(ImageFixtures.isBlue(try ImageFixtures.pixel(counter, x: 20, y: 10)), "Right side goes to the top")

        let mirrored = try XCTUnwrap(ImageTransform.apply(split, quarterTurns: 0, flipHorizontal: true, flipVertical: false))
        XCTAssertTrue(ImageFixtures.isBlue(try ImageFixtures.pixel(mirrored, x: 10, y: 20)))
        XCTAssertTrue(ImageFixtures.isRed(try ImageFixtures.pixel(mirrored, x: 70, y: 20)))

        let flippedTurned = try XCTUnwrap(ImageTransform.apply(split, quarterTurns: 1, flipHorizontal: true, flipVertical: false))
        XCTAssertTrue(ImageFixtures.isBlue(try ImageFixtures.pixel(flippedTurned, x: 20, y: 10)),
                      "Flip first (blue moves left), then turn (left goes to the top)")
    }

    func testRotateEngineNeedsAChange() async throws {
        let png = try ImageFixtures.write(try ImageFixtures.splitCGImage(), type: .png, name: "x.png")
        do {
            _ = try await RotateImageEngine().run(input: ToolInput(files: [try imported(png)]), options: .init()) { _ in }
            XCTFail("Expected nothingToDo")
        } catch let error as ToolError {
            guard case .nothingToDo = error else { return XCTFail("Got \(error)") }
        }
    }

    func testRotateEngineWritesTurnedImageInSameFormat() async throws {
        let png = try ImageFixtures.write(try ImageFixtures.splitCGImage(), type: .png, name: "turn.png")
        let output = try await RotateImageEngine().run(input: ToolInput(files: [try imported(png)]),
                                                       options: .init(quarterTurns: 1)) { _ in }
        let url = try XCTUnwrap(output.files.first)
        XCTAssertEqual(url.pathExtension, "png")
        let image = try ImageFixtures.read(url).image
        XCTAssertEqual([image.width, image.height], [40, 80])
    }

    // MARK: Watermark

    /// Every glyph of a line with the index of the character it came from.
    private func glyphs(of line: CTLine) -> [(index: CFIndex, glyph: CGGlyph)] {
        var result: [(index: CFIndex, glyph: CGGlyph)] = []
        for run in (CTLineGetGlyphRuns(line) as? [CTRun]) ?? [] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var indices = [CFIndex](repeating: 0, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetStringIndices(run, CFRange(location: 0, length: 0), &indices)
            for (index, glyph) in zip(indices, glyphs) {
                result.append((index: index, glyph: glyph))
            }
        }
        return result
    }

    func testArabicWatermarkIsShapedRightToLeft() {
        let color = CGColor(gray: 1, alpha: 1)
        let arabic = WatermarkRenderer.makeLine(text: "مِحوَل ٢٠٢٦", fontSize: 40, color: color)
        let runs = (CTLineGetGlyphRuns(arabic) as? [CTRun]) ?? []
        XCTAssertFalse(runs.isEmpty)
        XCTAssertTrue(runs.contains { CTRunGetStatus($0).contains(.rightToLeft) }, "Arabic must be laid out right to left")

        // Connected letters: in «محول» the م (initial form) and ح (medial form) must use
        // different glyphs than the same letters drawn alone. That is what shaping does.
        let word = "محول"
        let shaped = glyphs(of: WatermarkRenderer.makeLine(text: word, fontSize: 40, color: color))
        var reshaped = 0
        for (offset, letter) in word.enumerated() {
            let isolated = glyphs(of: WatermarkRenderer.makeLine(text: String(letter), fontSize: 40, color: color)).first?.glyph
            let inWord = shaped.first { $0.index == offset }?.glyph
            if let isolated, let inWord, isolated != inWord {
                reshaped += 1
            }
        }
        XCTAssertGreaterThanOrEqual(reshaped, 2, "Arabic letters must take their connected forms")

        let english = WatermarkRenderer.makeLine(text: "Mihwal", fontSize: 40, color: color)
        let englishRuns = (CTLineGetGlyphRuns(english) as? [CTRun]) ?? []
        XCTAssertFalse(englishRuns.contains { CTRunGetStatus($0).contains(.rightToLeft) })
    }

    func testWatermarkChangesPixelsAndKeepsSize() throws {
        let gray = try ImageFixtures.splitCGImage(width: 400, height: 300)
        for position in WatermarkPosition.allCases {
            var style = WatermarkStyle()
            style.text = "© عبدالله"
            style.color = .yellow
            style.opacity = 1
            style.size = .large
            style.position = position
            let marked = try XCTUnwrap(WatermarkRenderer.render(gray, style: style), "\(position)")
            XCTAssertEqual([marked.width, marked.height], [400, 300])
        }

        var centered = WatermarkStyle()
        centered.text = "WATERMARK"
        centered.color = .yellow
        centered.opacity = 1
        centered.size = .large
        let marked = try XCTUnwrap(WatermarkRenderer.render(gray, style: centered))
        // Yellow has a lot of green; the red/blue image has none. Scan the middle row.
        var changed = 0
        for x in stride(from: 0, to: 400, by: 4) {
            if try ImageFixtures.pixel(marked, x: x, y: 150).green > 100 {
                changed += 1
            }
        }
        XCTAssertGreaterThan(changed, 5, "Text should be drawn across the center")
    }

    func testWatermarkNeedsText() async throws {
        let png = try ImageFixtures.write(try ImageFixtures.splitCGImage(), type: .png, name: "w.png")
        do {
            _ = try await WatermarkImageEngine().run(input: ToolInput(files: [try imported(png)]), options: .init()) { _ in }
            XCTFail("Expected nothingToDo")
        } catch let error as ToolError {
            guard case .nothingToDo = error else { return XCTFail("Got \(error)") }
        }
    }

    func testWatermarkEngineWritesEveryImage() async throws {
        let first = try ImageFixtures.write(try ImageFixtures.splitCGImage(), type: .jpeg, name: "one.jpg")
        let second = try ImageFixtures.write(try ImageFixtures.splitCGImage(), type: .png, name: "two.png")
        var options = WatermarkImageEngine.Options()
        options.style.text = "مِحوَل"
        let recorder = ProgressRecorder()
        let output = try await WatermarkImageEngine().run(
            input: ToolInput(files: [try imported(first), try imported(second)]), options: options) { recorder.record($0) }
        XCTAssertEqual(output.files.map(\.pathExtension), ["jpg", "png"])
        XCTAssertEqual(recorder.values.last, 1)
    }
}
