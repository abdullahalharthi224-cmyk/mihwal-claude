import CoreText
import Foundation

enum Fonts {
    /// The system font for Latin text, with Geeza Pro for Arabic.
    ///
    /// The system's Arabic font (SF Arabic) draws dotted letters (ب ت ن ف ق …) as a dotless
    /// shape plus separate dot glyphs. That looks right, but in a PDF the dots become stray
    /// characters ("ڡ # ڡ 7" instead of "فق") when the text is copied or searched. Geeza Pro
    /// uses whole letters, so the text in our PDFs stays real, searchable Arabic.
    static func font(size: CGFloat, bold: Bool = false) -> CTFont {
        let base = CTFontCreateUIFontForLanguage(bold ? .emphasizedSystem : .system, size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let arabic = CTFontDescriptorCreateWithNameAndSize((bold ? "GeezaPro-Bold" : "GeezaPro") as CFString, size)
        let attributes = [kCTFontCascadeListAttribute: [arabic]] as CFDictionary
        let descriptor = CTFontDescriptorCreateCopyWithAttributes(CTFontCopyFontDescriptor(base), attributes)
        return CTFontCreateWithFontDescriptor(descriptor, size, nil)
    }
}
