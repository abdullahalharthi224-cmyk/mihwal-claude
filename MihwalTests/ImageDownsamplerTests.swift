import XCTest
@testable import Mihwal

final class ImageDownsamplerTests: XCTestCase {
    func testThumbnailFitsRequestedSize() throws {
        let url = try TestFixtures.makePNG(width: 400, height: 200)
        let image = try XCTUnwrap(ImageDownsampler.thumbnail(at: url, maxPixelSize: 100))
        XCTAssertEqual(image.width, 100)
        XCTAssertEqual(image.height, 50)
    }

    func testGarbageReturnsNil() throws {
        let url = try TestFixtures.makeGarbage(name: "fake.png")
        XCTAssertNil(ImageDownsampler.thumbnail(at: url, maxPixelSize: 100))
    }
}
