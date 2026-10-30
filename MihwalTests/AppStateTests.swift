import XCTest
@testable import Mihwal

final class AppStateTests: XCTestCase {
    private var suiteName = ""
    private var defaults = UserDefaults.standard

    override func setUpWithError() throws {
        suiteName = "MihwalTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testToggleFavoriteAddsThenRemoves() {
        let state = AppState(defaults: defaults)
        state.toggleFavorite(.merge)
        XCTAssertTrue(state.isFavorite(.merge))
        state.toggleFavorite(.merge)
        XCTAssertFalse(state.isFavorite(.merge))
    }

    func testFavoritesPersistAcrossLaunches() {
        AppState(defaults: defaults).toggleFavorite(.split)
        XCTAssertEqual(AppState(defaults: defaults).favorites, [.split])
    }

    func testRecordUseMovesToolToFrontWithoutDuplicates() {
        let state = AppState(defaults: defaults)
        state.recordUse(.merge)
        state.recordUse(.split)
        state.recordUse(.merge)
        XCTAssertEqual(state.recents, [.merge, .split])
    }

    func testRecentsAreCapped() {
        let state = AppState(defaults: defaults)
        for id in ToolID.allCases { state.recordUse(id) }
        XCTAssertEqual(state.recents.count, AppState.maxRecents)
        XCTAssertEqual(state.recents.first, ToolID.allCases.last)
    }

    func testClearRecentsPersists() {
        let state = AppState(defaults: defaults)
        state.recordUse(.merge)
        state.clearRecents()
        XCTAssertTrue(AppState(defaults: defaults).recents.isEmpty)
    }

    func testUnknownStoredIDsAreIgnored() {
        defaults.set(["merge", "notATool", "merge"], forKey: "favorites")
        XCTAssertEqual(AppState(defaults: defaults).favorites, [.merge])
    }
}
