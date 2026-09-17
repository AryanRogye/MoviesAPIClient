//
//  ContentView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import WebKit
import MoviesAPICore

enum TabID: Hashable {
    case home
    case library
    case history
    case settings
    case search
}

struct Root: View {

    private enum PlaybackRoute: Hashable {
        case player(UUID)
    }

    @State private var tmdbManager: TMDBManager?
    @State private var blockingService = BlockingService()
    @State private var playbackSession = PlaybackSession()

    @State private var selectedTab: TabID = .home
    @State private var homePath: [PlaybackRoute] = []
    @State private var libraryPath: [PlaybackRoute] = []
    @State private var historyPath: [PlaybackRoute] = []
    @State private var settingsPath: [PlaybackRoute] = []
    @State private var searchPath: [PlaybackRoute] = []
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var error: String?
    @State private var showError: Bool = false

    @Environment(\.tabViewBottomAccessoryPlacement) var placement

    var body: some View {
        VStack {
            if let tmdbManager {
                TabView(selection: $selectedTab) {

                    Tab("Home", systemImage: "house", value: .home) {
                        NavigationStack(path: $homePath) {
                            Home()
                                .navigationDestination(for: PlaybackRoute.self) { _ in
                                    PlaybackDestination()
                                }
                        }
                    }

                    Tab("Library", systemImage: "building.columns", value: .library) {
                        NavigationStack(path: $libraryPath) {
                            Library()
                                .navigationDestination(for: PlaybackRoute.self) { _ in
                                    PlaybackDestination()
                                }
                        }
                    }

                    Tab("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90", value: .history) {
                        NavigationStack(path: $historyPath) {
                            HistoryView()
                                .navigationDestination(for: PlaybackRoute.self) { _ in
                                    PlaybackDestination()
                                }
                        }
                    }

                    Tab("Settings", systemImage: "gear", value: .settings) {
                        NavigationStack(path: $settingsPath) {
                            SettingsView()
                                .navigationDestination(for: PlaybackRoute.self) { _ in
                                    PlaybackDestination()
                                }
                        }
                    }

                    Tab(value: .search, role: .search) {
                        NavigationStack(path: $searchPath) {
                            SearchTab()
                                .navigationDestination(for: PlaybackRoute.self) { _ in
                                    PlaybackDestination()
                                }
                        }
                    }
                }
                .onChange(of: playbackSession.activationID) {
                    playbackSession.sourceTab = selectedTab
                }
                .tabViewBottomAccessory(isEnabled: playbackSession.isActive) {
                    HStack(spacing: 10) {
                        Button(action: playbackSession.stop) {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, height: 40)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)

                        Button(action: returnToPlayback) {
                            HStack(spacing: 10) {
                                if let posterPath = playbackSession.playback?.posterPath,
                                   let posterURL = URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)") {
                                    AsyncImage(url: posterURL) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Color.secondary.opacity(0.2)
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(.rect(cornerRadius: 5))
                                }

                                Text(playbackSession.playback?.title ?? "Now Playing")
                                    .lineLimit(1)

                                Spacer()

                                Image(systemName: "chevron.up")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(4)
                    .padding(.horizontal, 8)
                }
                .environment(tmdbManager)
                .environment(blockingService)
                .environment(playbackSession)
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

    private func returnToPlayback() {
        guard let sourceTab = playbackSession.sourceTab else { return }

        selectedTab = sourceTab
        let route = PlaybackRoute.player(playbackSession.activationID)

        func append(_ route: PlaybackRoute, to path: inout [PlaybackRoute]) {
            guard path.last != route else { return }
            path.append(route)
        }

        switch sourceTab {
        case .home:
            append(route, to: &homePath)
        case .library:
            append(route, to: &libraryPath)
        case .history:
            append(route, to: &historyPath)
        case .settings:
            append(route, to: &settingsPath)
        case .search:
            append(route, to: &searchPath)
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
