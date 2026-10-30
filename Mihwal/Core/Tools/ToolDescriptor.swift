import SwiftUI
import UniformTypeIdentifiers

/// Everything the Home screen and the "Open in" flow need to know about a tool.
/// The engine itself lives in Tools/<ToolName>/ and is plugged in through `makeView`.
struct ToolDescriptor: Identifiable {
    let id: ToolID
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let symbol: String
    let category: ToolCategory
    /// File types this tool can open. Used to suggest tools for shared files.
    let accepts: [UTType]
    /// Merge, Images → PDF and the image tools take several files at once.
    var allowsMultipleFiles = false
    /// The tool's screen, given any files that were shared into the app.
    /// `nil` until the tool is built; a generic screen is shown meanwhile.
    var makeView: (@MainActor ([ImportedFile]) -> AnyView)? = nil

    var isAvailable: Bool { makeView != nil }
}
