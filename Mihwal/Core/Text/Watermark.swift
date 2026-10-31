import CoreGraphics
import CoreText
import Foundation

enum WatermarkSize: String, Hashable, Sendable, CaseIterable {
    case small
    case medium
    case large

    /// Text height as a fraction of the image's shorter side, so the mark looks the
    /// same on every image of a batch and in the small preview.
    var fraction: CGFloat {
        switch self {
        case .small: return 0.045
        case .medium: return 0.075
        case .large: return 0.12
        }
    }
}

enum WatermarkColor: String, Hashable, Sendable, CaseIterable {
    case white
    case black
    case red
    case yellow
    case blue

    var components: (red: CGFloat, green: CGFloat, blue: CGFloat) {
        switch self {
        case .white: return (1, 1, 1)
        case .black: return (0, 0, 0)
        case .red: return (0.92, 0.18, 0.18)
        case .yellow: return (1, 0.84, 0.1)
        case .blue: return (0.1, 0.45, 0.95)
        }
    }

    func cgColor(alpha: CGFloat) -> CGColor {
        let c = components
        return CGColor(red: c.red, green: c.green, blue: c.blue, alpha: alpha)
    }
}

/// Where the mark goes. Corners are named by how they look on screen (not leading/trailing),
/// so they mean the same thing in Arabic and English.
enum WatermarkPosition: String, Hashable, Sendable, CaseIterable {
    case center
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case tiled
}

struct WatermarkStyle: Hashable, Sendable {
    var text = ""
    var size: WatermarkSize = .medium
    var color: WatermarkColor = .white
    var opacity: Double = 0.5
    /// Degrees, counter-clockwise (positive rises from left to right).
    var angle: Double = 0
    var position: WatermarkPosition = .center

    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Draws text on an image with Core Text. CTLine shapes Arabic (connected letters) and
/// orders mixed Arabic/English/numbers with the Unicode bidi algorithm; no glyphs are
/// drawn by hand.
enum WatermarkRenderer {
    static func makeLine(text: String, fontSize: CGFloat, color: CGColor) -> CTLine {
        let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, fontSize, nil)
            ?? CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        return CTLineCreateWithAttributedString(string as CFAttributedString)
    }

    /// Draws the photo, then the mark on top. Used for images and their previews.
    static func render(_ image: CGImage, style: WatermarkStyle) -> CGImage? {
        guard !style.trimmedText.isEmpty,
              let context = ImageCanvas.context(width: image.width, height: image.height,
                                                like: image, opaque: !image.hasAlpha) else { return nil }
        let size = CGSize(width: image.width, height: image.height)
        context.draw(image, in: CGRect(origin: .zero, size: size))
        draw(style, in: context, size: size)
        return context.makeImage()
    }

    /// Draws the mark into any context whose origin is the bottom-left corner of an area of
    /// `size` (a photo, or a PDF page). Text size is relative to the shorter side.
    static func draw(_ style: WatermarkStyle, in context: CGContext, size: CGSize) {
        let text = style.trimmedText
        guard !text.isEmpty, size.width > 0, size.height > 0 else { return }
        let width = size.width
        let height = size.height

        let shorterSide = min(width, height)
        let fontSize = max(8, shorterSide * style.size.fraction)
        let color = style.color.cgColor(alpha: CGFloat(min(1, max(0.05, style.opacity))))
        let line = makeLine(text: text, fontSize: fontSize, color: color)

        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let lineHeight = ascent + descent
        let radians = CGFloat(style.angle) * .pi / 180

        // Half the size of the rotated text's bounding box, to keep corners inside the area.
        let halfWidth = (abs(cos(radians)) * lineWidth + abs(sin(radians)) * lineHeight) / 2
        let halfHeight = (abs(sin(radians)) * lineWidth + abs(cos(radians)) * lineHeight) / 2
        let margin = shorterSide * 0.04

        func drawLine(at center: CGPoint) {
            context.saveGState()
            context.translateBy(x: center.x, y: center.y)
            context.rotate(by: radians)
            context.textMatrix = .identity
            context.textPosition = CGPoint(x: -lineWidth / 2, y: -lineHeight / 2 + descent)
            CTLineDraw(line, context)
            context.restoreGState()
        }

        // Core Graphics' y axis points up: "top" is a large y.
        let left = margin + halfWidth
        let right = width - margin - halfWidth
        let top = height - margin - halfHeight
        let bottom = margin + halfHeight

        switch style.position {
        case .center: drawLine(at: CGPoint(x: width / 2, y: height / 2))
        case .topLeft: drawLine(at: CGPoint(x: left, y: top))
        case .topRight: drawLine(at: CGPoint(x: right, y: top))
        case .bottomLeft: drawLine(at: CGPoint(x: left, y: bottom))
        case .bottomRight: drawLine(at: CGPoint(x: right, y: bottom))
        case .tiled:
            let stepX = max(halfWidth * 2 + shorterSide * 0.12, 1)
            let stepY = max(halfHeight * 2 + shorterSide * 0.12, 1)
            var row = 0
            var y = -stepY / 2
            // The cap keeps a tiny font on a huge area from drawing thousands of copies.
            var drawn = 0
            while y < height + stepY, drawn < 600 {
                var x = (row % 2 == 0 ? 0 : stepX / 2) - stepX / 2
                while x < width + stepX, drawn < 600 {
                    drawLine(at: CGPoint(x: x, y: y))
                    drawn += 1
                    x += stepX
                }
                y += stepY
                row += 1
            }
        }
    }
}
