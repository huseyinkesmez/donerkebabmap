//
//  AppTheme.swift
//  donerkebabmap
//

import SwiftUI

/// Uygulama genelinde tutarlı görünüm için marka renkleri ve stilleri.
///
/// İki katman var:
/// - **Arayüz aksanı** (`primary`/`secondary`/`brandGradient`): okunaklı
///   kırmızı-turuncu. Tab, buton, pin dairesi, rozet gibi UI öğelerinde.
/// - **Logo rengi** (`amber`): görsel kimlikteki amber; yalnızca `DonerConeLogo`
///   dolgusunda kullanılır.
enum AppTheme {
    /// Ana arayüz aksanı — okunaklı kırmızı (#DB3421).
    static let primary = Color(red: 0.86, green: 0.20, blue: 0.13)
    /// İkincil aksan — turuncu (#F5871F), degradenin üst ucu.
    static let secondary = Color(red: 0.96, green: 0.53, blue: 0.13)

    /// Logo dolgusu — sıcak amber (#F0A828). Sadece logo için.
    static let amber = Color(red: 0.94, green: 0.66, blue: 0.16)
    /// Kontur / mürekkep rengi (#1D1D1F).
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    /// Kırık beyaz zemin (#F7F5F1).
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.95)

    /// Pin dairesi, rozet ve buton arka planlarında kullanılan aksan degradesi.
    static let brandGradient = LinearGradient(
        colors: [secondary, primary],
        startPoint: .top,
        endPoint: .bottom
    )
}
