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
    /// The tool's screen. `nil` until the tool is built, then a "Coming soon" screen is shown.
    var makeView: (() -> AnyView)? = nil

    var isAvailable: Bool { makeView != nil }
}
