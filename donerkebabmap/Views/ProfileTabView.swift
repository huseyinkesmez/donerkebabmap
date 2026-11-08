//
//  ProfileTabView.swift
//  donerkebabmap
//

import SwiftUI
import UIKit
import WebKit

struct ProfileTabView: View {
    private static let appStoreURL = URL(string: "https://apps.apple.com/app/id6790539934")!
    private static let writeReviewURL = URL(string: "https://apps.apple.com/app/id6790539934?action=write-review")!
    private static let supportURL = URL(string: "https://huseyinkesmez.github.io/donerkebabmap/support.html")!
    private static let privacyPolicyURL = URL(string: "https://huseyinkesmez.github.io/donerkebabmap/privacy-policy.html")!

    @AppStorage("appearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue
    @AppStorage("preferredMapsApp") private var preferredMapsRaw = PreferredMapsApp.ask.rawValue
    @Environment(\.openURL) private var openURL

    @State private var webPage: WebPage?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearanceRaw) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.titleKey).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Directions") {
                    Picker("Open with", selection: $preferredMapsRaw) {
                        ForEach(PreferredMapsApp.allCases) { app in
                            Text(app.titleKey).tag(app.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("About") {
                    Button {
                        openURL(Self.writeReviewURL)
                    } label: {
                        MoreRow(icon: "star.fill", title: "Rate the App")
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: Self.appStoreURL) {
                        MoreRow(icon: "square.and.arrow.up", title: "Share the App")
                    }
                    .buttonStyle(.plain)

                    Button {
                        webPage = WebPage(title: "Support", url: Self.supportURL)
                    } label: {
                        MoreRow(icon: "questionmark.circle.fill", title: "Support")
                    }
                    .buttonStyle(.plain)

                    Button {
                        webPage = WebPage(title: "Privacy Policy", url: Self.privacyPolicyURL)
                    } label: {
                        MoreRow(icon: "hand.raised.fill", title: "Privacy Policy")
                    }
                    .buttonStyle(.plain)

                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("More")
        }
        .sheet(item: $webPage) { page in
            WebPageView(page: page)
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

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct WebPage: Identifiable {
    let title: LocalizedStringKey
    let url: URL
    var id: URL { url }
}

/// One of our own web pages in a sheet, titled by name. Uses a web view because
/// Safari's in-app browser always shows the page's address at the top.
private struct WebPageView: View {
    let page: WebPage

    @Environment(\.dismiss) private var dismiss
    @State private var loadState = WebView.LoadState.loading

    var body: some View {
        NavigationStack {
            WebView(url: page.url, loadState: $loadState)
                .ignoresSafeArea(edges: .bottom)
                .overlay {
                    switch loadState {
                    case .loading:
                        ProgressView()
                    case .loaded:
                        EmptyView()
                    case .failed:
                        ContentUnavailableView(
                            "Couldn't Load This Page",
                            systemImage: "wifi.slash",
                            description: Text("Check your internet connection and try again.")
                        )
                        .background(Color(.systemBackground))
                    }
                }
                .navigationTitle(page.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("Close")
                    }
                }
        }
    }
}

private struct WebView: UIViewRepresentable {
    enum LoadState {
        case loading, loaded, failed
    }

    let url: URL
    @Binding var loadState: LoadState

    func makeCoordinator() -> Coordinator { Coordinator(loadState: $loadState) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        // No white flash in dark mode while the page loads.
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var loadState: LoadState

        init(loadState: Binding<LoadState>) {
            _loadState = loadState
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loadState = .loaded
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            loadState = .failed
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            loadState = .failed
        }

        /// Links to our own pages stay here; others (e.g. mailto:) go to the system.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor action: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard action.navigationType == .linkActivated,
                  let url = action.request.url,
                  url.host != webView.url?.host else {
                decisionHandler(.allow)
                return
            }
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }
    }
}

private struct MoreRow: View {
    let icon: String
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(AppTheme.primaryAccent)
                .frame(width: 28, height: 28)
                .background(AppTheme.primaryAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

            Text(title)
                .foregroundStyle(.primary)
                .adaptiveText()

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    ProfileTabView()
}
