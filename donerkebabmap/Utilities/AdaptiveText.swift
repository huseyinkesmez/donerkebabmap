//
//  AdaptiveText.swift
//  donerkebabmap
//

import SwiftUI

/// Buton/etiket metinlerinin dar ekranda, uzun çevirilerde (DE/FR) veya büyük
/// Dynamic Type boyutlarında satır kırmak/kırpılmak yerine sığacak kadar
/// küçülmesini sağlar.
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
    /// Tek satıra sığdırır; gerekirse metni `minimumScale` oranına kadar küçültür.
    func adaptiveText(minimumScale: CGFloat = 0.75) -> some View {
        modifier(AdaptiveTextModifier(minimumScale: minimumScale))
    }
}
