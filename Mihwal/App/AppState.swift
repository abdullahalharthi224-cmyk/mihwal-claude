import Foundation
import Observation

/// App-wide user state: favorite tools and recently used tools, saved in UserDefaults.
@Observable
final class AppState {
    static let maxRecents = 6

    private(set) var favorites: [ToolID]
    private(set) var recents: [ToolID]

    private let defaults: UserDefaults

    private enum Keys {
        static let favorites = "favorites"
        static let recents = "recents"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favorites = Self.load(Keys.favorites, from: defaults)
        recents = Array(Self.load(Keys.recents, from: defaults).prefix(Self.maxRecents))
    }

    func isFavorite(_ id: ToolID) -> Bool {
        favorites.contains(id)
    }

    func toggleFavorite(_ id: ToolID) {
        if let index = favorites.firstIndex(of: id) {
            favorites.remove(at: index)
        } else {
            favorites.append(id)
        }
        defaults.set(favorites.map(\.rawValue), forKey: Keys.favorites)
    }

    /// Moves the tool to the front of the recents list.
    func recordUse(_ id: ToolID) {
        var updated = recents.filter { $0 != id }
        updated.insert(id, at: 0)
        recents = Array(updated.prefix(Self.maxRecents))
        defaults.set(recents.map(\.rawValue), forKey: Keys.recents)
    }

    func clearRecents() {
        recents = []
        defaults.removeObject(forKey: Keys.recents)
    }

    private static func load(_ key: String, from defaults: UserDefaults) -> [ToolID] {
        var seen = Set<ToolID>()
        return (defaults.stringArray(forKey: key) ?? [])
            .compactMap(ToolID.init(rawValue:))
            .filter { seen.insert($0).inserted }
    }
}
