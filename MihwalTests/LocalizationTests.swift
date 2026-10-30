import XCTest
@testable import Mihwal

/// Guards the String Catalog against format mistakes. A placeholder of the wrong type
/// (for example an Int reaching a %@) crashes the app at runtime, so this is checked
/// for every string, every language and every plural form.
final class LocalizationTests: XCTestCase {
    /// Counts that select every Arabic plural form: zero, one, two, few (3–10),
    /// many (11–99) and other (100+).
    private let pluralCounts = [0, 1, 2, 3, 11, 100]
    private let languages = ["ar", "en"]

    // MARK: Static audit of the catalog file

    func testEveryTranslationUsesTheSamePlaceholdersAsItsKey() throws {
        var problems: [String] = []
        for (key, entry) in try Self.catalogEntries() {
            let expected = Self.placeholders(in: key)
            for (language, value) in entry.values {
                let found = Self.placeholders(in: value.text)
                if found == expected { continue }
                // A plural form may leave out the number (e.g. «ملفان») only when the
                // count is the string's one and only argument.
                if value.isPluralForm && expected.count == 1 && found.isEmpty { continue }
                problems.append("\"\(key)\" [\(language)\(value.form.map { "/\($0)" } ?? "")]: expected \(expected), found \(found) in \"\(value.text)\"")
            }
        }
        XCTAssertTrue(problems.isEmpty, "Placeholder mismatches:\n" + problems.joined(separator: "\n"))
    }

    func testPluralStringsTakeOnlyTheCount() throws {
        for (key, entry) in try Self.catalogEntries() where entry.isPlural {
            XCTAssertEqual(Self.placeholders(in: key), ["lld"],
                           "Plural string \"\(key)\" must have exactly one %lld argument")
        }
    }

    // MARK: Formatting at runtime, as the app does

    func testEveryPluralStringFormatsForAllCountsInBothLanguages() throws {
        let pluralKeys = try Self.catalogEntries().filter { $0.value.isPlural }.map { $0.key }
        XCTAssertFalse(pluralKeys.isEmpty)
        for language in languages {
            for key in pluralKeys {
                let format = try localizedFormat(key, language: language)
                for count in pluralCounts {
                    let text = String(format: format, locale: Locale(identifier: language), count)
                    assertFormatted(text, key: key, language: language, detail: "count \(count)")
                }
            }
        }
    }

    func testEveryFormatStringFormatsInBothLanguages() throws {
        let keys = try Self.catalogEntries().map { $0.key }.filter { !Self.placeholders(in: $0).isEmpty }
        for language in languages {
            for key in keys {
                let format = try localizedFormat(key, language: language)
                let arguments: [CVarArg] = Self.placeholders(in: key).map { type -> CVarArg in
                    if type == "@" {
                        return "report.pdf" as NSString
                    }
                    return 2
                }
                let text = String(format: format, locale: Locale(identifier: language), arguments: arguments)
                assertFormatted(text, key: key, language: language, detail: "sample arguments")
            }
        }
    }

    // MARK: Helpers

    private func assertFormatted(_ text: String, key: String, language: String, detail: String) {
        XCTAssertFalse(text.isEmpty, "\"\(key)\" [\(language)] is empty for \(detail)")
        XCTAssertFalse(text.contains("%"), "\"\(key)\" [\(language)] left a placeholder for \(detail): \(text)")
        XCTAssertFalse(text.contains("(null)"), "\"\(key)\" [\(language)] printed (null) for \(detail)")
    }

    private func localizedFormat(_ key: String, language: String) throws -> String {
        let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"),
                                 "\(language).lproj is missing from the app")
        let bundle = try XCTUnwrap(Bundle(path: path))
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    /// Placeholder types in order, e.g. "%lld files · %@" → ["lld", "@"].
    static func placeholders(in text: String) -> [String] {
        let pattern = try? NSRegularExpression(pattern: "%(?:\\d+\\$)?(lld|ld|d|@|f)")
        let range = NSRange(text.startIndex..., in: text)
        return pattern?.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: 1), in: text).map { String(text[$0]) }
        } ?? []
    }

    // MARK: Reading the catalog source

    struct CatalogValue {
        let text: String
        let form: String?
        var isPluralForm: Bool { form != nil }
    }

    struct CatalogEntry {
        var values: [(language: String, value: CatalogValue)] = []
        var isPlural = false
    }

    /// Reads Mihwal/Resources/Localizable.xcstrings from the repository (simulator tests can
    /// read the Mac's files), so mistakes are reported by name instead of as a crash.
    static func catalogEntries() throws -> [(key: String, value: CatalogEntry)] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Mihwal/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])

        return strings.keys.sorted().map { key -> (key: String, value: CatalogEntry) in
            var entry = CatalogEntry()
            let localizations = (strings[key] as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
            for (language, raw) in localizations {
                guard let localization = raw as? [String: Any] else { continue }
                if let unit = localization["stringUnit"] as? [String: Any], let text = unit["value"] as? String {
                    entry.values.append((language, CatalogValue(text: text, form: nil)))
                }
                let variations = localization["variations"] as? [String: Any]
                if let plural = variations?["plural"] as? [String: Any] {
                    entry.isPlural = true
                    for (form, rawUnit) in plural {
                        let unit = (rawUnit as? [String: Any])?["stringUnit"] as? [String: Any]
                        if let text = unit?["value"] as? String {
                            entry.values.append((language, CatalogValue(text: text, form: form)))
                        }
                    }
                }
            }
            return (key, entry)
        }
    }
}
