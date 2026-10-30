import Foundation
import Photos

enum PhotoSaver {
    /// Adds image files to the photo library. Asks for "add only" access the first time.
    static func save(_ urls: [URL]) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ToolError.photosAccessDenied
        }
        try await PHPhotoLibrary.shared().performChanges {
            for url in urls {
                let request = PHAssetCreationRequest.forAsset()
                // A new photo: dated now, so it shows up with today's pictures.
                request.creationDate = Date()
                request.addResource(with: .photo, fileURL: url, options: nil)
            }
        }
    }
}
