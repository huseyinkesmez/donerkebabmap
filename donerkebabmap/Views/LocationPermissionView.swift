//
//  LocationPermissionView.swift
//  donerkebabmap
//

import SwiftUI

/// Konum izni reddedildiğinde/kısıtlandığında gösterilen bilgilendirme ekranı.
/// Kullanıcıyı sistem Ayarlar'ına yönlendirir.
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
