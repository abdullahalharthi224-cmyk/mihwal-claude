import SwiftUI
import UIKit

/// The one place for spacing, corner radii, sizes, colors and motion.
/// Views use these tokens instead of raw numbers.
enum DS {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let s: CGFloat = 10
        static let m: CGFloat = 18
        static let l: CGFloat = 24
    }

    enum Size {
        static let toolIcon: CGFloat = 42
        static let chipIcon: CGFloat = 28
        static let gridMinimum: CGFloat = 150
    }

    enum Palette {
        static let background = Color(uiColor: .systemGroupedBackground)
        static let card = Color(uiColor: .secondarySystemGroupedBackground)
        static let accent = Color.accentColor
    }

    enum Motion {
        static let standard: Animation = .snappy(duration: 0.3)
        static let press: Animation = .snappy(duration: 0.18)
    }
}

extension ToolCategory {
    var tint: Color {
        switch self {
        case .organize: return .indigo
        case .convert: return .teal
        case .images: return .orange
        }
    }
}
