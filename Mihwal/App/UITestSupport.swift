#if DEBUG
import Foundation
import UIKit

/// Used only by the UI tests (Debug builds; never in the Release IPA):
/// `-uiTestTool <ToolID> -uiTestFiles <path|path>` opens that tool with those files.
enum UITestSupport {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestTool")
    }

    static func initialRoute() async -> ToolRoute? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let toolIndex = arguments.firstIndex(of: "-uiTestTool"), toolIndex + 1 < arguments.count,
              let tool = ToolID(rawValue: arguments[toolIndex + 1]) else { return nil }
        let paths: [String]
        if let filesIndex = arguments.firstIndex(of: "-uiTestFiles"), filesIndex + 1 < arguments.count {
            paths = arguments[filesIndex + 1].split(separator: "|").map(String.init)
        } else {
            paths = []
        }
        let files = await Task.detached {
            paths.compactMap { try? FileStore.importCopy(of: URL(fileURLWithPath: $0), coordinated: false) }
        }.value
        return ToolRoute(tool: tool, files: files)
    }

    @MainActor
    static func prepare() {
        // Faster, steadier UI tests.
        UIView.setAnimationsEnabled(false)
    }
}
#endif
