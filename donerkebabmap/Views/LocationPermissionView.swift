//
//  LocationPermissionView.swift
//  donerkebabmap
//

import SwiftUI

/// Shown when location permission is denied or restricted.
/// Sends the user to the system Settings.
struct LocationPermissionView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label("Location Needed", systemImage: "location.slash.fill")
        } description: {
            Text("Enable location access to see doner and kebab spots near you.")
        } actions: {
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            .adaptiveText()
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(AppTheme.primary)
        }
    }
}

#Preview {
    LocationPermissionView()
}
