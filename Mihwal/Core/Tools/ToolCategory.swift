import Foundation

enum ToolCategory: String, CaseIterable, Identifiable {
    case organize
    case convert
    case images

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .organize: return "Organize PDF"
        case .convert: return "Convert"
        case .images: return "Images"
        }
    }

    var symbol: String {
        switch self {
        case .organize: return "doc.on.doc"
        case .convert: return "arrow.left.arrow.right"
        case .images: return "photo"
        }
    }
}
