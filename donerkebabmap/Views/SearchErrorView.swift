//
//  SearchErrorView.swift
//  donerkebabmap
//

import SwiftUI

/// Yer araması başarısız olduğunda (ör. internet yok) gösterilen,
/// "Tekrar Dene" butonlu bilgilendirme ekranı.
struct SearchErrorView: View {
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't Load Places", systemImage: "wifi.slash")
        } description: {
            Text("Check your internet connection and try again.")
        } actions: {
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(AppTheme.primary)
        }
    }
}

#Preview {
    SearchErrorView(retry: {})
}
