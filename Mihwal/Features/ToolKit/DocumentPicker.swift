import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Files app picker. `asCopy: true` makes iOS hand us a private copy of each file,
/// so there is no security-scoped access to manage and nothing can expire before we copy it.
/// The delegate reports every outcome (picked or cancelled) through one callback.
struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let allowsMultipleSelection: Bool
    /// Picked URLs, or an empty array when the user cancelled.
    let onFinish: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFinish: ([URL]) -> Void

        init(onFinish: @escaping ([URL]) -> Void) {
            self.onFinish = onFinish
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            Log.importing.info("Document picker returned \(urls.count) file(s)")
            onFinish(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            Log.importing.info("Document picker cancelled")
            onFinish([])
        }
    }
}
