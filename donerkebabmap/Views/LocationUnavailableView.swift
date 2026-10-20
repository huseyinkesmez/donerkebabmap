//
//  LocationUnavailableView.swift
//  donerkebabmap
//

import SwiftUI

/// İzin verilmiş olmasına rağmen konum alınamadığında (ör. kapalı mekan,
/// konum servisleri kapalı) gösterilir. Sonsuz "yükleniyor" yerine çıkış yolu.
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
