import Foundation

/// Stable identifier for every tool. The raw value is persisted (favorites, recents),
/// so never rename a case; add new ones instead.
enum ToolID: String, CaseIterable, Codable, Hashable {
    // Organize PDF
    case merge
    case split
    case compressPDF
    case rotatePDF
    case deletePages
    case extractPages
    case reversePages
    case pageNumbers
    case watermarkPDF
    case stripMetadata
    case removeRestrictions

    // Convert
    case pdfToWord
    case pdfToText
    case textToPDF
    case imagesToPDF
    case pdfToImages

    // Images
    case convertImage
    case compressImage
    case resizeImage
    case rotateImage
    case watermarkImage
}
