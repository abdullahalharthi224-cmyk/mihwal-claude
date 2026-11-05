import XCTest

/// Opens every finished tool in the real app (on a simulator), gives it a file from
/// samples/, presses its button the way a person would, and checks the result screen.
final class ToolUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: Helpers

    private func samplePath(_ name: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("samples/\(name)")
            .path
    }

    private func open(_ tool: String, with files: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestTool", tool,
            "-uiTestFiles", files.map(samplePath).joined(separator: "|"),
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
        return app
    }

    private func waitUntilEnabled(_ element: XCUIElement, timeout: TimeInterval = 20,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) never appeared", file: file, line: line)
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: element)
        wait(for: [enabled], timeout: timeout)
    }

    private func run(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons["tool.run"]
        waitUntilEnabled(button, file: file, line: line)
        button.tap()
    }

    private func expectResult(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let success = app.descendants(matching: .any)["result.success"]
        let appeared = success.waitForExistence(timeout: 90)
        let alert = app.alerts.firstMatch
        XCTAssertTrue(appeared, "No result screen. Alert: \(alert.exists ? alert.label : "none")", file: file, line: line)
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 20), "\(element) not found", file: file, line: line)
        element.tap()
    }

    private func type(_ text: String, into field: XCUIElement) {
        tap(field)
        field.typeText(text)
    }

    // MARK: Organize PDF

    func testMerge() {
        let app = open("merge", with: ["6-ten-pages.pdf", "1-metadata.pdf"])
        run(app)
        expectResult(app)
    }

    func testSplitEveryPage() {
        let app = open("split", with: ["1-metadata.pdf"])
        tap(app.buttons["Every page"])
        run(app)
        expectResult(app)
    }

    func testCompressPDFStrong() {
        let app = open("compressPDF", with: ["7-scan.pdf"])
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Strong'")).firstMatch)
        run(app)
        expectResult(app)
    }

    func testRotatePages() {
        let app = open("rotatePDF", with: ["6-ten-pages.pdf"])
        tap(app.buttons["Rotate Right"])
        run(app)
        expectResult(app)
    }

    func testDeletePages() {
        let app = open("deletePages", with: ["6-ten-pages.pdf"])
        tap(app.buttons["Page 2"])
        run(app)
        expectResult(app)
    }

    func testExtractPages() {
        let app = open("extractPages", with: ["6-ten-pages.pdf"])
        tap(app.buttons["Page 2"])
        run(app)
        expectResult(app)
    }

    func testReverseOrder() {
        let app = open("reversePages", with: ["6-ten-pages.pdf"])
        run(app)
        expectResult(app)
    }

    func testPageNumbers() {
        let app = open("pageNumbers", with: ["5-with-link.pdf"])
        run(app)
        expectResult(app)
    }

    func testWatermarkPDF() {
        let app = open("watermarkPDF", with: ["6-ten-pages.pdf"])
        type("Mihwal\n", into: app.textFields["watermark.text"])
        run(app)
        expectResult(app)
    }

    func testRemoveMetadata() {
        let app = open("stripMetadata", with: ["1-metadata.pdf"])
        run(app)
        expectResult(app)
    }

    /// Also checks the password sheet: a wrong password keeps it open, the right one runs the tool.
    func testUnlockWithPasswordSheet() {
        let app = open("removeRestrictions", with: ["2-password-1234.pdf"])
        run(app)
        let field = app.textFields["password.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 20), "Password sheet didn't appear")
        field.tap()
        field.typeText("0000\n")
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Sheet must stay open after a wrong password")
        XCTAssertNotEqual(field.value as? String, "0000", "Field is cleared for the next try")
        field.typeText("1234\n")
        expectResult(app)
    }

    /// Open password, then the owner password, all in the same sheet.
    func testOwnerPasswordFlowInOneSheet() {
        let app = open("reversePages", with: ["4-both-open-1111-owner-2222.pdf"])
        run(app)
        let field = app.textFields["password.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 20))
        field.tap()
        field.typeText("1111\n")
        XCTAssertTrue(app.navigationBars["Owner password needed"].waitForExistence(timeout: 10),
                      "The same sheet should now ask for the owner password")
        field.typeText("2222\n")
        expectResult(app)
    }

    // MARK: Images

    func testConvertImage() {
        let app = open("convertImage", with: ["photo.jpg"])
        run(app)
        expectResult(app)
    }

    func testCompressImages() {
        let app = open("compressImage", with: ["photo.jpg", "logo.png"])
        run(app)
        expectResult(app)
    }

    func testResizeImage() {
        let app = open("resizeImage", with: ["photo.jpg"])
        run(app)
        expectResult(app)
    }

    func testRotateImage() {
        let app = open("rotateImage", with: ["photo.jpg"])
        tap(app.buttons["Rotate Clockwise"])
        run(app)
        expectResult(app)
    }

    func testWatermarkImage() {
        let app = open("watermarkImage", with: ["logo.png"])
        type("Mihwal\n", into: app.textFields["watermark.text"])
        run(app)
        expectResult(app)
    }

    // MARK: Convert

    func testPDFToText() {
        let app = open("pdfToText", with: ["6-ten-pages.pdf"])
        run(app)
        expectResult(app)
        XCTAssertTrue(app.buttons["result.copyText"].waitForExistence(timeout: 5), "Copy Text button")
    }

    func testPDFToWord() {
        let app = open("pdfToWord", with: ["1-metadata.pdf"])
        run(app)
        expectResult(app)
    }

    func testTextToPDFTyped() {
        let app = open("textToPDF", with: [])
        let editor = app.textViews["text.editor"]
        tap(editor)
        editor.typeText("Hello from Mihwal")
        run(app)
        expectResult(app)
    }

    func testImagesToPDF() {
        let app = open("imagesToPDF", with: ["photo.jpg", "logo.png"])
        run(app)
        expectResult(app)
    }

    func testPDFToImages() {
        let app = open("pdfToImages", with: ["1-metadata.pdf"])
        run(app)
        expectResult(app)
    }
}
