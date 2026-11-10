import Foundation

/// Which way text runs, from its letters (Unicode "strong" characters).
enum TextDirection {
    static func isStrongRTL(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x0590...0x05FF, 0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF,
             0xFB1D...0xFDFF, 0xFE70...0xFEFF:
            return scalar.properties.isAlphabetic
        default:
            return false
        }
    }

    static func isStrongLTR(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isAlphabetic && !isStrongRTL(scalar)
    }

    /// True/false from the first letter; nil when there is no letter at all ("21", "—").
    static func firstStrongIsRTL(_ text: String) -> Bool? {
        for scalar in text.unicodeScalars {
            if isStrongRTL(scalar) { return true }
            if isStrongLTR(scalar) { return false }
        }
        return nil
    }

    /// A document is right-to-left when most of its letters are Arabic (or Hebrew).
    static func mostlyRightToLeft(_ text: String) -> Bool {
        var rtl = 0
        var ltr = 0
        for scalar in text.unicodeScalars {
            if isStrongRTL(scalar) { rtl += 1 } else if isStrongLTR(scalar) { ltr += 1 }
        }
        return rtl > ltr
    }
}
