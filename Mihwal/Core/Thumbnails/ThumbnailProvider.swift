import PDFKit
import UIKit

/// Makes and caches small previews of PDF pages and images, off the main thread.
/// The cache is limited by memory cost and iOS empties it automatically under pressure.
actor ThumbnailProvider {
    static let shared = ThumbnailProvider()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 64 * 1024 * 1024
        return cache
    }()

    /// A few open PDFs are kept so scrolling a page grid doesn't reopen the file each time.
    private var documents: [URL: PDFDocument] = [:]
    private let maxOpenDocuments = 4

    func pdfPage(_ url: URL, index: Int, maxPixelSize: CGFloat, password: String?) -> UIImage? {
        let key = "\(url.path)#\(index)#\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let document = document(for: url, password: password),
              let page = document.page(at: index) else { return nil }
        let image = page.thumbnail(of: CGSize(width: maxPixelSize, height: maxPixelSize), for: .mediaBox)
        store(image, for: key)
        return image
    }

    func image(_ url: URL, maxPixelSize: CGFloat) -> UIImage? {
        let key = "\(url.path)#image#\(Int(maxPixelSize))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let cgImage = ImageDownsampler.thumbnail(at: url, maxPixelSize: maxPixelSize) else { return nil }
        let image = UIImage(cgImage: cgImage)
        store(image, for: key)
        return image
    }

    /// Call when a file is removed so its PDF is closed.
    func forget(_ url: URL) {
        documents[url] = nil
    }

    private func document(for url: URL, password: String?) -> PDFDocument? {
        let document: PDFDocument
        if let open = documents[url] {
            document = open
        } else {
            guard let opened = PDFDocument(url: url) else { return nil }
            if documents.count >= maxOpenDocuments {
                documents.removeAll()
            }
            documents[url] = opened
            document = opened
        }
        if document.isLocked, let password {
            _ = document.unlock(withPassword: password)
        }
        return document.isLocked ? nil : document
    }

    private func store(_ image: UIImage, for key: NSString) {
        let pixels = image.size.width * image.scale * image.size.height * image.scale
        cache.setObject(image, forKey: key, cost: Int(pixels) * 4)
    }
}
