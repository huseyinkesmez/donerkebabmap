//
//  AppTheme.swift
//  donerkebabmap
//

import SwiftUI
import UIKit

/// Brand colors and styles for a consistent look across the app.
///
/// There are two layers:
/// - **UI accent** (`primary`/`secondary`/`brandGradient`): the "Ember"
///   coral-to-raspberry gradient for tabs, buttons, pin circles, badges and
///   similar UI.
/// - **Logo color** (`amber`): the visual identity's amber, used only for the
///   `DonerConeLogo` fill.
enum AppTheme {
    /// Main UI accent — raspberry red (#E8174F).
    static let primary = Color(red: 0.910, green: 0.090, blue: 0.310)
    /// Secondary accent — soft coral (#FF8A57), the top of the gradient. Close
    /// enough to `primary` in hue that the gradient blends softly.
    static let secondary = Color(red: 1.000, green: 0.541, blue: 0.341)

    /// **Text/icon** variant of the brand color: slightly darker in light mode,
    /// lighter in dark mode. On lightly tinted backgrounds (e.g. badges) `primary`
    /// fell below WCAG AA in both modes; this color passes.
    /// Keep using `primary` for fills and button backgrounds.
    static let primaryAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.000, green: 0.478, blue: 0.604, alpha: 1) // #FF7A9A
            : UIColor(red: 0.690, green: 0.063, blue: 0.227, alpha: 1) // #B0103A
    })

    /// Logo fill — warm amber (#F0A828). Logo only.
    static let amber = Color(red: 0.94, green: 0.66, blue: 0.16)
    /// Outline / ink color (#1D1D1F).
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.12)
    /// Off-white background (#F7F5F1).
    static let cream = Color(red: 0.97, green: 0.96, blue: 0.95)

    /// Accent gradient for pin circles, badges and button backgrounds.
    static let brandGradient = LinearGradient(
        colors: [secondary, primary],
        startPoint: .top,
        endPoint: .bottom
    )
}
