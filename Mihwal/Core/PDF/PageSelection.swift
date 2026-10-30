import Foundation

/// Which pages of a PDF are selected (0-based indices). Pure value type, easy to test.
struct PageSelection: Equatable {
    private(set) var pages: Set<Int> = []

    var count: Int { pages.count }
    var isEmpty: Bool { pages.isEmpty }
    var sorted: [Int] { pages.sorted() }

    func contains(_ index: Int) -> Bool {
        pages.contains(index)
    }

    mutating func toggle(_ index: Int) {
        if pages.contains(index) {
            pages.remove(index)
        } else {
            pages.insert(index)
        }
    }

    mutating func selectAll(pageCount: Int) {
        pages = Set(0..<max(0, pageCount))
    }

    mutating func clear() {
        pages.removeAll()
    }
}
