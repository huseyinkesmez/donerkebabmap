//
//  ContentView.swift
//  donerkebabmap
//
//  Created by Huseyin Kesmez on 12.07.2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var placesViewModel = PlacesViewModel()

    var body: some View {
        TabView {
            MapTabView()
                .tabItem {
                    Label("Map", image: "TabMap")
                }

            ListTabView()
                .tabItem {
                    Label("List", image: "TabList")
                }

            ProfileTabView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle")
                }
        }
        .tint(AppTheme.primary)
        .environmentObject(locationManager)
        .environmentObject(placesViewModel)
        .onReceive(locationManager.$userLocation) { coordinate in
            guard let coordinate else { return }
            placesViewModel.loadPlacesIfNeeded(around: coordinate)
        }
    }
}

#Preview {
    ContentView()
}
