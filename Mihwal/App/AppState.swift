import Foundation
import Observation

/// App-wide user state: favorite tools and recently used tools, saved in UserDefaults.
@Observable
final class AppState {
    static let maxRecents = 6

    private(set) var favorites: [ToolID]
    private(set) var recents: [ToolID]

    /// Home's navigation stack, so "Open in" can jump straight into a tool.
    var path: [ToolRoute] = []
    /// Files shared into the app, waiting for the user to pick a tool.
    var incoming: IncomingFiles?
    var incomingError: ToolError?

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

    // MARK: "Open in" / Share to Mihwal

    /// Copies a file another app shared with us, then asks which tool to use.
    @MainActor
    func receive(_ url: URL) async {
        let result = await Task.detached(priority: .userInitiated) { () -> Result<ImportedFile, ToolError> in
            defer {
                if FileStore.isInboxFile(url) { FileStore.remove(url) }
            }
            do {
                return .success(try FileStore.importCopy(of: url))
            } catch {
                return .failure(ToolError(error))
            }
        }.value

        switch result {
        case .success(let file):
            incoming = IncomingFiles(files: [file])
        case .failure(let error):
            incomingError = error
        }
    }

    /// Opens a tool with files already loaded, replacing whatever screen was open.
    func open(_ tool: ToolID, with files: [ImportedFile]) {
        incoming = nil
        path = [ToolRoute(tool: tool, files: files)]
    }

    private static func load(_ key: String, from defaults: UserDefaults) -> [ToolID] {
        var seen = Set<ToolID>()
        return (defaults.stringArray(forKey: key) ?? [])
            .compactMap(ToolID.init(rawValue:))
            .filter { seen.insert($0).inserted }
    }
}

struct IncomingFiles: Identifiable {
    let id = UUID()
    let files: [ImportedFile]
}
