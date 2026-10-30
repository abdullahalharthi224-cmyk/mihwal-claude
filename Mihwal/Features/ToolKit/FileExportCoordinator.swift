import UIKit

/// "Save to Files". The export picker is presented directly by UIKit on top of the current
/// screen. Wrapping it in a SwiftUI .sheet (as before) embeds it in another controller,
/// and in export mode its Save/Move button then stays disabled.
/// Every outcome is reported; nothing is swallowed.
@MainActor
final class FileExportCoordinator: NSObject, UIDocumentPickerDelegate {
    enum Outcome: Equatable {
        case saved(count: Int)
        case cancelled
        case failed(ToolError)
    }

    private var completion: ((Outcome) -> Void)?
    /// Kept alive while it is on screen (the picker only holds its delegate weakly).
    private var picker: UIDocumentPickerViewController?

    /// Builds the picker, after checking the files still exist.
    func makePicker(for urls: [URL], completion: @escaping (Outcome) -> Void) -> Result<UIDocumentPickerViewController, ToolError> {
        let missing = urls.filter { !FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty, missing.isEmpty else {
            Log.tools.error("Export failed: \(missing.count) result file(s) missing")
            return .failure(.resultUnavailable)
        }
        let picker = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        picker.delegate = self
        self.picker = picker
        self.completion = completion
        return .success(picker)
    }

    func export(_ urls: [URL], completion: @escaping (Outcome) -> Void) {
        switch makePicker(for: urls, completion: completion) {
        case .failure(let error):
            completion(.failed(error))
        case .success(let picker):
            guard let presenter = Self.topViewController() else {
                Log.tools.error("Export failed: no view controller to present from")
                finish(.failed(.unknown(message: String(localized: "The Files app couldn't be opened. Please try again."))))
                return
            }
            Log.tools.info("Presenting export picker for \(urls.count) file(s)")
            presenter.present(picker, animated: true)
        }
    }

    // MARK: UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        Log.tools.info("Export picker saved \(urls.count) file(s)")
        finish(.saved(count: urls.count))
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        Log.tools.info("Export picker cancelled")
        finish(.cancelled)
    }

    private func finish(_ outcome: Outcome) {
        let completion = self.completion
        self.completion = nil
        picker = nil
        completion?(outcome)
    }

    /// The screen currently on top (e.g. the result sheet), to present from.
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
