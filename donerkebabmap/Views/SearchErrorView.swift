//
//  SearchErrorView.swift
//  donerkebabmap
//

import SwiftUI

/// Shown when the place search fails (e.g. no internet), with a
/// "Try Again" button.
struct SearchErrorView: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't Load Places", systemImage: "wifi.slash")
        } description: {
            Text("Check your internet connection and try again.")
        } actions: {
            Button("Try Again", action: retry)
                .adaptiveText()
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AppTheme.primary)
        }
    }
}

#Preview {
    SearchErrorView(retry: {})
}
