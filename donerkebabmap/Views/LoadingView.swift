//
//  LoadingView.swift
//  donerkebabmap
//
//  Görsel kimlikteki Loading.dc.html'in SwiftUI karşılığı: süzülen döner
//  logosu + genişleyen halkalar + puls noktaları.
//

import SwiftUI

struct LoadingView: View {
    @State private var animating = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                expandingRing(delay: 0)
                expandingRing(delay: 0.9)

                DonerGlyph()
                    .frame(width: 78, height: 103)
                    .offset(y: animating ? -10 : 0)
                    .animation(
                        .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                        value: animating
                    )
            }
            .frame(width: 150, height: 150)

            Text("Searching for nearby places…")
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AppTheme.primary)
                        .frame(width: 8, height: 8)
                        .opacity(animating ? 1 : 0.25)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
        }
        .onAppear { animating = true }
    }

    private func expandingRing(delay: Double) -> some View {
        Circle()
            .fill(AppTheme.primary.opacity(0.3))
            .frame(width: 92, height: 92)
            .scaleEffect(animating ? 1.6 : 0.7)
            .opacity(animating ? 0 : 0.5)
            .animation(
                .easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(delay),
                value: animating
            )
    }
}

#Preview {
    LoadingView()
}
