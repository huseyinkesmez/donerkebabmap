//
//  RootView.swift
//  donerkebabmap
//

import SwiftUI

/// Uygulama açılışında kısa bir marka splash ekranı gösterip ardından
/// ana içeriğe geçer.
struct RootView: View {
    @State private var isShowingSplash = true
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @StateObject private var favoriteStore = FavoriteStore()

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        ZStack {
            ContentView()
                .environmentObject(favoriteStore)

            if !hasSeenOnboarding {
                OnboardingView {
                    withAnimation(.easeOut(duration: 0.4)) {
                        hasSeenOnboarding = true
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }

            if isShowingSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.5)) {
                isShowingSplash = false
            }
        }
    }
}

private struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    private var isDark: Bool { colorScheme == .dark }
    private var background: Color { isDark ? Color(red: 0.11, green: 0.11, blue: 0.12) : AppTheme.cream }
    private var textColor: Color { isDark ? AppTheme.cream : AppTheme.ink }

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()

            VStack(spacing: 20) {
                DonerConeLogo(outline: isDark ? AppTheme.cream : AppTheme.ink)
                    .frame(width: 120, height: 158)
                    .scaleEffect(appeared ? 1 : 0.6)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 6) {
                    Text("Doner Kebab Map")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundStyle(textColor)

                    Text("The best doner spots near you")
                        .font(.subheadline)
                        .foregroundStyle(textColor.opacity(0.6))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
        }
        .task {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }
}

#Preview {
    RootView()
}
