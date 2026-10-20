//
//  AppearanceMode.swift
//  donerkebabmap
//

import SwiftUI

/// The user's appearance preference. Persisted with `@AppStorage` and applied
/// at the root as `.preferredColorScheme`.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Color scheme passed to SwiftUI; nil for `system` (follow the system).
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
