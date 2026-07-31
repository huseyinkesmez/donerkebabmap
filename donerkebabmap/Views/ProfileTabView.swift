//
//  ProfileTabView.swift
//  donerkebabmap
//

import SwiftUI
import UIKit

struct ProfileTabView: View {
    /// Favoriler listesinde doğrudan kaç tane gösterilsin; üstü "Show all"a gider.
    private static let previewFavoriteCount = 3

    private let contactEmail = "hsynkesmez97@gmail.com"

    @EnvironmentObject private var favoriteStore: FavoriteStore
    @EnvironmentObject private var locationManager: LocationManager
    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue
    @Environment(\.openURL) private var openURL

    @State private var selectedPlace: DonerPlace?
    @State private var isShowingMail = false
    @State private var isShowingMailFallback = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Favorites") {
                    if favoriteStore.favorites.isEmpty {
                        favoritesEmptyState
                    } else {
                        ForEach(previewFavorites) { favorite in
                            Button {
                                selectedPlace = DonerPlace(
                                    favorite: favorite,
                                    userLocation: locationManager.userLocation
                                )
                            } label: {
                                FavoriteRow(favorite: favorite)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { favoriteStore.remove(at: $0) }

                        if favoriteStore.favorites.count > Self.previewFavoriteCount {
                            NavigationLink {
                                AllFavoritesView()
                            } label: {
                                Label(
                                    "Show all (\(favoriteStore.favorites.count))",
                                    systemImage: "list.bullet"
                                )
                                .font(.subheadline.weight(.semibold))
                            }
                        }
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearanceRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.titleKey).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)

                    Button(action: contactByEmail) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.footnote)
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(AppTheme.brandGradient, in: RoundedRectangle(cornerRadius: 7))

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Contact")
                                    .foregroundStyle(.primary)
                                Text("Send us a message")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("More")
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailCard(place: place)
        }
        .sheet(isPresented: $isShowingMail) {
            MailView(recipient: contactEmail, subject: "Doner Kebab Map")
                .ignoresSafeArea()
        }
        .alert("Contact", isPresented: $isShowingMailFallback) {
            Button("Copy Email") {
                UIPasteboard.general.string = contactEmail
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("No mail account is set up on this device. You can reach us at \(contactEmail).")
        }
    }

    private var previewFavorites: [FavoritePlace] {
        Array(favoriteStore.favorites.prefix(Self.previewFavoriteCount))
    }

    /// Mail hesabı tanımlıysa uygulama içi yazma penceresini açar; değilse
    /// (ör. simülatörde hesap yoksa) sistemin `mailto:` akışına düşer.
    private func contactByEmail() {
        if MailView.canSendMail {
            isShowingMail = true
            return
        }

        // Mail hesabı yoksa mailto:'yu dene; onu da açacak bir uygulama
        // yoksa (ör. simülatör) adresi gösteren uyarıya düş.
        guard let url = URL(string: "mailto:\(contactEmail)") else {
            isShowingMailFallback = true
            return
        }
        openURL(url) { accepted in
            if !accepted { isShowingMailFallback = true }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            DonerConeLogo()
                .frame(width: 60, height: 80)

            VStack(spacing: 2) {
                Text("Doner Kebab Map")
                    .font(.headline)
                    .fontWeight(.bold)

                Text("The best doner spots near you")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var favoritesEmptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart")
                .foregroundStyle(.secondary)

            Text("You haven't added any favorites yet.")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// Tüm favorileri gösteren, "Show all"dan açılan alt sayfa. Profildeki
/// NavigationStack'in içine push edilir.
struct AllFavoritesView: View {
    @EnvironmentObject private var favoriteStore: FavoriteStore
    @EnvironmentObject private var locationManager: LocationManager

    @State private var selectedPlace: DonerPlace?

    var body: some View {
        List {
            ForEach(favoriteStore.favorites) { favorite in
                Button {
                    selectedPlace = DonerPlace(
                        favorite: favorite,
                        userLocation: locationManager.userLocation
                    )
                } label: {
                    FavoriteRow(favorite: favorite)
                }
                .buttonStyle(.plain)
            }
            .onDelete { favoriteStore.remove(at: $0) }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if favoriteStore.favorites.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "heart",
                    description: Text("You haven't added any favorites yet.")
                )
            }
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailCard(place: place)
        }
    }
}

private struct FavoriteRow: View {
    let favorite: FavoritePlace

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.subheadline)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text(favorite.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !favorite.address.isEmpty {
                    Text(favorite.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

#Preview {
    ProfileTabView()
        .environmentObject(FavoriteStore())
        .environmentObject(LocationManager())
}
