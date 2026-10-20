//
//  LocationUnavailableView.swift
//  donerkebabmap
//

import SwiftUI

/// Shown when permission is granted but no location could be determined
/// (e.g. indoors, Location Services off). A way out instead of loading forever.
struct LocationUnavailableView: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Location Unavailable", systemImage: "location.slash")
        } description: {
            Text("We couldn't determine your location. Make sure Location Services are on, then try again.")
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
    LocationUnavailableView(retry: {})
}
