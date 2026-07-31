//
//  AppearanceMode.swift
//  donerkebabmap
//

import SwiftUI

/// Kullanıcının seçtiği görünüm tercihi. `@AppStorage` ile kalıcı saklanır ve
/// kökte `.preferredColorScheme` olarak uygulanır.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// SwiftUI'ye verilecek renk şeması; `system` için nil (sistemi takip et).
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
