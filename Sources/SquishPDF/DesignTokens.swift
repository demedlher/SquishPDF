import SwiftUI

/// Design Tokens - Bauhaus & Golden Ratio Inspired
/// Mathematical foundations for harmonious UI design
///
/// Core principles:
///   - 8-point grid for spatial consistency
///   - Golden ratio (φ = 1.618) for proportions
///   - Modular scale (1.25) for restrained typography
///   - Fibonacci-adjacent spacing for natural rhythm

enum Design {

    // MARK: - Mathematical Constants

    enum Constants {
        static let phi: CGFloat = 1.618033988749895
        static let phiInverse: CGFloat = 0.618033988749895
        static let phiSquared: CGFloat = 2.618033988749895

        /// Golden ratio layout splits
        static let goldenMajor: CGFloat = 0.618
        static let goldenMinor: CGFloat = 0.382
    }

    // MARK: - Spacing (8-Point Grid, Fibonacci-adjacent)
    // Sequence: 4 → 8 → 16 → 24 → 40 → 64 → 104 → 168

    enum Space {
        static let none: CGFloat = 0
        static let xxs: CGFloat = 4      // Half-step for tight adjustments
        static let xs: CGFloat = 8       // Base unit - minimum spacing
        static let sm: CGFloat = 16      // 2× - small gaps, padding
        static let md: CGFloat = 24      // 3× - standard component spacing
        static let lg: CGFloat = 40      // 5× (Fibonacci) - section spacing
        static let xl: CGFloat = 64      // 8× (Fibonacci) - major section breaks
        static let xxl: CGFloat = 104    // 13× (Fibonacci) - page-level spacing
        static let xxxl: CGFloat = 168   // 21× (Fibonacci) - hero/feature spacing

        // Semantic aliases
        static let inline: CGFloat = xxs
        static let iconGap: CGFloat = xs
        static let inputPaddingX: CGFloat = sm
        static let inputPaddingY: CGFloat = xs
        static let buttonPaddingX: CGFloat = sm
        static let buttonPaddingY: CGFloat = xs
        static let cardPadding: CGFloat = md
        static let stackGap: CGFloat = sm
        static let sectionGap: CGFloat = lg
        static let pageMargin: CGFloat = xl
    }

    // MARK: - Typography (Modular Scale 1.25)
    // Sequence: 10 → 13 → 16 → 20 → 25 → 31 → 39 → 49

    enum Font {
        static let xs: CGFloat = 10      // Fine print, captions
        static let sm: CGFloat = 13      // Secondary text, labels
        static let base: CGFloat = 16    // Body text
        static let md: CGFloat = 20      // Emphasized body, large text
        static let lg: CGFloat = 25      // Subheadings
        static let xl: CGFloat = 31      // H3
        static let xxl: CGFloat = 39     // H2
        static let xxxl: CGFloat = 49    // H1

        // Semantic mapping
        static let caption: CGFloat = xs
        static let label: CGFloat = sm
        static let body: CGFloat = base
        static let bodyLarge: CGFloat = md
        static let heading: CGFloat = lg
    }

    // MARK: - Border Radii

    enum Radius {
        static let none: CGFloat = 0
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let full: CGFloat = 9999
    }

    // MARK: - Components

    enum Button {
        static let minHeight: CGFloat = 40
        static let minWidth: CGFloat = 64

        enum Height {
            static let sm: CGFloat = 32
            static let md: CGFloat = 40
            static let lg: CGFloat = 48
        }

        enum Padding {
            static let smX: CGFloat = 12
            static let smY: CGFloat = 6
            static let mdX: CGFloat = 16
            static let mdY: CGFloat = 8
            static let lgX: CGFloat = 24
            static let lgY: CGFloat = 12
        }
    }

    enum Icon {
        static let xs: CGFloat = 16
        static let sm: CGFloat = 20
        static let md: CGFloat = 24
        static let lg: CGFloat = 32
        static let xl: CGFloat = 40
    }

    enum Card {
        static let padding: CGFloat = Space.md
        static let radius: CGFloat = Radius.md
    }

    // MARK: - Touch Targets

    enum Touch {
        static let minimum: CGFloat = 40     // WCAG minimum
        static let comfortable: CGFloat = 48
    }
}
