//
//  ContentView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

struct Root: View {

    private enum TabID: Hashable {
        case home
        case settings
        case search
    }

    @State private var tmdbManager: TMDBManager?
    @State private var blockingService = BlockingService()

    @State private var selectedTab: TabID = .home
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var error: String?
    @State private var showError: Bool = false

    var body: some View {
        VStack {
            if let tmdbManager {
                TabView(selection: $selectedTab) {
                    Tab("Home", systemImage: "house", value: .home) {
                        NavigationStack {
                            Home()
                        }
                    }

                    Tab("Settings", systemImage: "gear", value: .settings) {
                        NavigationStack {
                            SettingsView()
                        }
                    }

                    Tab(value: .search, role: .search) {
                        NavigationStack {
                            SearchTab()
                        }
                    }
                }
                .environment(tmdbManager)
                .environment(blockingService)
                .modifier(
                    SearchTabModifier(
                        isSearchTabSelected: selectedTab == .search,
                        searchText: $searchText
                    ) {
                        search(using: tmdbManager)
                    }
                )
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .task {
            do {
                let manager = try TMDBManager()
                self.tmdbManager = manager
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }

    private func search(using manager: TMDBManager) {
        guard !isSearching else { return }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            manager.clearSearchResults()
            return
        }

        isSearching = true
        Task {
            defer { isSearching = false }
            do {
                try await manager.search(query)
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }

}

private struct SearchTabModifier: ViewModifier {

    let isSearchTabSelected: Bool
    @Binding var searchText: String
    let submit: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isSearchTabSelected {
            content
                .searchable(text: $searchText, prompt: "Search movies, TV, and people")
                .tabViewSearchActivation(.searchTabSelection)
                .onSubmit(of: .search, submit)
        } else {
            content
        }
    }
}

#Preview {
    Root()
}
