import PhotosUI
import SwiftUI

/// "Files" and (for image tools) "Photos" buttons.
struct ImportSourceButtons: View {
    let files: FileListModel
    @Binding var photoItems: [PhotosPickerItem]
    let onChooseFiles: () -> Void
    var isProminent = false

    var body: some View {
        if isProminent {
            buttons
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        } else {
            buttons
                .buttonStyle(.borderless)
        }
    }

    private var buttons: some View {
        HStack(spacing: DS.Spacing.s) {
            Button(action: onChooseFiles) {
                Label("Files", systemImage: "folder")
            }
            if files.acceptsImages {
                PhotosPicker(selection: $photoItems,
                             maxSelectionCount: files.allowsMultiple ? 50 : 1,
                             matching: .images,
                             preferredItemEncoding: .current) {
                    Label("Photos", systemImage: "photo.on.rectangle")
                }
            }
        }
    }
}
