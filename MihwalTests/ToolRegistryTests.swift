import XCTest
@testable import Mihwal

final class ToolRegistryTests: XCTestCase {
    func testRegistryHasAll21Tools() {
        XCTAssertEqual(ToolRegistry.all.count, 21)
    }

    func testEveryToolIDIsRegisteredExactlyOnce() {
        let ids = ToolRegistry.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate tool IDs")
        for id in ToolID.allCases {
            XCTAssertNotNil(ToolRegistry.descriptor(for: id), "\(id) is not registered")
        }
    }

    func testCategoryCounts() {
        XCTAssertEqual(ToolRegistry.tools(in: .organize).count, 11)
        XCTAssertEqual(ToolRegistry.tools(in: .convert).count, 5)
        XCTAssertEqual(ToolRegistry.tools(in: .images).count, 5)
    }

    func testEveryToolAcceptsAtLeastOneType() {
        for tool in ToolRegistry.all {
            XCTAssertFalse(tool.accepts.isEmpty, "\(tool.id) accepts no file types")
            XCTAssertFalse(tool.symbol.isEmpty, "\(tool.id) has no symbol")
        }
    }

    func testSearchMatchesEnglishTitleIgnoringCase() {
        let ids = ToolRegistry.search("merge").map(\.id)
        XCTAssertTrue(ids.contains(.merge))
    }

    func testSearchWithBlankQueryReturnsEverything() {
        XCTAssertEqual(ToolRegistry.search("   ").count, ToolRegistry.all.count)
    }

    func testSearchWithNoMatchReturnsEmpty() {
        XCTAssertTrue(ToolRegistry.search("zzqqxx").isEmpty)
    }

    /// Proves the String Catalog was compiled into the app with Arabic for every tool.
    func testEveryToolHasArabicTitleAndSubtitle() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "ar", ofType: "lproj"),
                                 "ar.lproj missing from the app bundle")
        let arabic = try XCTUnwrap(Bundle(path: path))
        let keys = ToolRegistry.all.flatMap { [$0.title.key, $0.subtitle.key] }
            + ToolCategory.allCases.map(\.title.key)
        for key in keys {
            let value = arabic.localizedString(forKey: key, value: nil, table: nil)
            XCTAssertNotEqual(value, key, "No Arabic translation for \"\(key)\"")
        }
    }
}
