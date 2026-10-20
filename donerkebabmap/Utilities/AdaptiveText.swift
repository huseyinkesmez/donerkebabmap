//
//  AdaptiveText.swift
//  donerkebabmap
//

import SwiftUI

/// Lets button/label text shrink to fit instead of wrapping or clipping on
/// narrow screens, with long translations (DE/FR), or at large Dynamic Type
/// sizes.
private struct AdaptiveTextModifier: ViewModifier {
    let minimumScale: CGFloat

    func body(content: Content) -> some View {
        content
            .lineLimit(1)
            .minimumScaleFactor(minimumScale)
            .allowsTightening(true)
    }
}

extension View {
    /// Keeps text on one line, scaling it down to `minimumScale` if needed.
    func adaptiveText(minimumScale: CGFloat = 0.75) -> some View {
        modifier(AdaptiveTextModifier(minimumScale: minimumScale))
    }
}
