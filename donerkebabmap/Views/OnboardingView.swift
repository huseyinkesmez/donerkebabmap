//
//  OnboardingView.swift
//  donerkebabmap
//

import SwiftUI

/// İlk açılışta gösterilen, atlanabilir (Skip) 3 sayfalık tanıtım akışı.
/// Bittiğinde `onFinish` çağrılır; RootView bunu kalıcı olarak işaretler.
struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var page = 0

    private let pages = OnboardingPage.all

    private var isDark: Bool { colorScheme == .dark }
    private var background: Color {
        isDark ? Color(red: 0.11, green: 0.11, blue: 0.12) : AppTheme.cream
    }
    private var textColor: Color { isDark ? AppTheme.cream : AppTheme.ink }
    private var isLastPage: Bool { page == pages.count - 1 }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 0) {
                skipButton

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(page: pages[index], textColor: textColor)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator
                    .padding(.bottom, 24)

                primaryButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
            }
        }
    }

    private var skipButton: some View {
        HStack {
            Spacer()
            Button("Skip", action: onFinish)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(textColor.opacity(0.55))
                .opacity(isLastPage ? 0 : 1)
                .disabled(isLastPage)
                .padding(.horizontal, 20)
        }
        .frame(height: 44)
        .padding(.top, 8)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? textColor.opacity(0.85) : textColor.opacity(0.18))
                    .frame(width: index == page ? 20 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: page)
    }

    private var primaryButton: some View {
        Button {
            if isLastPage {
                onFinish()
            } else {
                withAnimation { page += 1 }
            }
        } label: {
            Text(isLastPage ? "Get Started" : "Next")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(textColor.opacity(0.9), in: Capsule())
        }
    }
}

// MARK: - Sayfa modeli & tek sayfa görünümü

private struct OnboardingPage: Identifiable {
    let id = UUID()
    /// SF Symbol adı; nil ise marka logosu (DonerConeLogo) gösterilir.
    let symbol: String?
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    static let all: [OnboardingPage] = [
        OnboardingPage(
            symbol: nil,
            title: "Welcome to Doner Kebab Map",
            message: "Discover the best döner, kebab and gyro spots around you — all on one map."
        ),
        OnboardingPage(
            symbol: "map.fill",
            title: "Explore Nearby",
            message: "Spots near you appear as pins. Browse them on the map or as a distance-sorted list."
        ),
        OnboardingPage(
            symbol: "arrow.triangle.turn.up.right.diamond.fill",
            title: "Directions & Favorites",
            message: "Get directions in one tap with Apple or Google Maps, and save the places you love."
        )
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let textColor: Color

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            illustration

            VStack(spacing: 14) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(textColor)

                Text(page.message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(textColor.opacity(0.65))
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var illustration: some View {
        if let symbol = page.symbol {
            Image(systemName: symbol)
                .font(.system(size: 60, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 140, height: 140)
                .background(
                    AppTheme.brandGradient,
                    in: RoundedRectangle(cornerRadius: 36, style: .continuous)
                )
                .shadow(color: AppTheme.primary.opacity(0.35), radius: 16, y: 8)
        } else {
            DonerConeLogo()
                .frame(width: 130, height: 170)
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
