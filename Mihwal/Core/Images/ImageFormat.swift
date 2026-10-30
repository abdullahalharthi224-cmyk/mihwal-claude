import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Formats Mihwal can write. WebP is read-only on iOS (ImageIO has no WebP encoder),
/// and HEIC is offered only where the device can encode it.
enum ImageFormat: String, CaseIterable, Hashable, Sendable, Identifiable {
    case jpeg
    case png
    case heic

    var id: String { rawValue }

    var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        }
    }

    /// Not translated: format names are the same in every language.
    var displayName: String {
        switch self {
        case .jpeg: return "JPG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        }
    }

    var isLossy: Bool { self != .png }

    private static let encodableIdentifiers: Set<String> =
        Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])

    var canEncode: Bool {
        Self.encodableIdentifiers.contains(utType.identifier)
    }

    static var exportable: [ImageFormat] {
        allCases.filter(\.canEncode)
    }

    /// The format to write when the user wants to keep the original one.
    /// PNG stays PNG, JPEG stays JPEG, HEIC stays HEIC (if it can be written);
    /// everything else (WebP, GIF, TIFF…) becomes PNG when it has transparency, else JPEG.
    static func preserving(_ type: UTType, hasAlpha: Bool) -> ImageFormat {
        if type.conforms(to: .png) { return .png }
        if type.conforms(to: .jpeg) { return .jpeg }
        if type.conforms(to: .heic) || type.conforms(to: .heif), ImageFormat.heic.canEncode { return .heic }
        return hasAlpha ? .png : .jpeg
    }
}
