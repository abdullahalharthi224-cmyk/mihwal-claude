import XCTest
@testable import Mihwal

final class ZipWriterTests: XCTestCase {
    func testCRC32KnownVector() {
        // The standard check value for CRC-32/ISO-HDLC.
        XCTAssertEqual(CRC32.checksum(Data("123456789".utf8)), 0xCBF4_3926)
        XCTAssertEqual(CRC32.checksum(Data()), 0)
    }

    func testArchiveStructureAndContents() throws {
        let folder = try TestFixtures.scratchDirectory()
        let zipURL = folder.appendingPathComponent("test.zip")
        let entries = [
            ZipWriter.Entry(path: "a.txt", data: Data("hello".utf8)),
            ZipWriter.Entry(path: "مجلد/ب.txt", data: Data("مرحبا".utf8)),
        ]
        try ZipWriter.write(entries: entries, to: zipURL)
        let zip = try Data(contentsOf: zipURL)

        // Local header of the first entry.
        XCTAssertEqual(zip.readLE32(at: 0), 0x0403_4B50)
        XCTAssertEqual(zip.readLE16(at: 6), 0x0800, "UTF-8 name flag")
        XCTAssertEqual(zip.readLE32(at: 14), CRC32.checksum(Data("hello".utf8)))
        let nameLength = Int(zip.readLE16(at: 26))
        let firstName = String(decoding: zip[30..<(30 + nameLength)], as: UTF8.self)
        XCTAssertEqual(firstName, "a.txt")
        let firstData = zip[(30 + nameLength)..<(30 + nameLength + 5)]
        XCTAssertEqual(String(decoding: firstData, as: UTF8.self), "hello")

        // End of central directory record: last 22 bytes.
        let end = zip.count - 22
        XCTAssertEqual(zip.readLE32(at: end), 0x0605_4B50)
        XCTAssertEqual(zip.readLE16(at: end + 10), 2, "entry count")
        let centralSize = Int(zip.readLE32(at: end + 12))
        let centralOffset = Int(zip.readLE32(at: end + 16))
        XCTAssertEqual(centralOffset + centralSize, end)
        XCTAssertEqual(zip.readLE32(at: centralOffset), 0x0201_4B50)
    }

    func testDuplicateFileNamesAreRenamed() throws {
        let first = try TestFixtures.makePNG(width: 4, height: 4, name: "page.png")
        let second = try TestFixtures.makePNG(width: 4, height: 4, name: "page.png")
        let zipURL = try TestFixtures.scratchDirectory().appendingPathComponent("pages.zip")
        try ZipWriter.write(files: [first, second], to: zipURL)
        let text = String(decoding: try Data(contentsOf: zipURL), as: UTF8.self)
        XCTAssertTrue(text.contains("page.png"))
        XCTAssertTrue(text.contains("page 2.png"))
    }

    func testDosDateTimeEncoding() {
        var parts = DateComponents()
        parts.calendar = Calendar(identifier: .gregorian)
        parts.timeZone = .current
        parts.year = 2026; parts.month = 10; parts.day = 30
        parts.hour = 13; parts.minute = 45; parts.second = 20
        let stamp = ZipWriter.dosDateTime(parts.date ?? Date())
        XCTAssertEqual(stamp.date, UInt16((2026 - 1980) << 9 | 10 << 5 | 30))
        XCTAssertEqual(stamp.time, UInt16(13 << 11 | 45 << 5 | 10))
    }
}

private extension Data {
    func readLE16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func readLE32(at offset: Int) -> UInt32 {
        (0..<4).reduce(UInt32(0)) { $0 | UInt32(self[offset + $1]) << (8 * UInt32($1)) }
    }
}
