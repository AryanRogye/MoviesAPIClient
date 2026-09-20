//
//  Home.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import SwiftUI
import SwiftData

public struct Home: View {

    @Environment(TMDBManager.self) var tmdbManager

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var selectedFilter: LibraryFilter = .all

    public init() {}

    var filteredResults: [KTTrendingResult] {
        switch selectedFilter {
        case .all:
            tmdbManager.trendingResults
        case .tv:
            tmdbManager.trendingResults.filter { result in
                result.mediaType == .tv
            }
        case .movies:
            tmdbManager.trendingResults.filter { result in
                result.mediaType == .movie
            }
        }
    }


    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Trending")
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .padding(.top, 8)
                HomeListView(
                    contents: filteredResults,
                    error: $error,
                    showError: $showError
                )

                if selectedFilter == .movies || selectedFilter == .all {
                    Text("Now Playing Movies")
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top, 8)
                    HomeListView(
                        contents: tmdbManager.nowPlayingMovies,
                        error: $error,
                        showError: $showError
                    )
                }

                if selectedFilter == .tv || selectedFilter == .all {
                    Text("Popular TV Shows")
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top, 8)
                    HomeListView(
                        contents: tmdbManager.popularTV,
                        error: $error,
                        showError: $showError
                    )
                }

                if selectedFilter == .movies || selectedFilter == .all {
                    Text("Popular Movies")
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top, 8)
                    HomeListView(
                        contents: tmdbManager.popularMovies,
                        error: $error,
                        showError: $showError
                    )
                }

                if selectedFilter == .tv || selectedFilter == .all {
                    Text("Top Rated TV Shows")
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top, 8)
                    HomeListView(
                        contents: tmdbManager.topRatedTV,
                        error: $error,
                        showError: $showError
                    )
                }

                if selectedFilter == .movies || selectedFilter == .all {
                    Text("Top Rated Movies")
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top, 8)
                    HomeListView(
                        contents: tmdbManager.topRatedMovies,
                        error: $error,
                        showError: $showError
                    )
                }
            }
            .padding(.bottom)
        }
        .navigationTitle("Home")
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .toolbar {

#if os(macOS)
            ToolbarSpacer(.flexible)
#endif

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(LibraryFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Image(systemName: "line.horizontal.3.decrease")
                }
            }
        }
        .task {
            do {
                try await tmdbManager.trending()
                try? await Task.sleep(for: .seconds(1))
                try await tmdbManager.nowPlaying()
                try? await Task.sleep(for: .seconds(1))
                try await tmdbManager.popularTV()
                try? await Task.sleep(for: .seconds(1))
                try await tmdbManager.popularMovie()
                try? await Task.sleep(for: .seconds(1))
                try await tmdbManager.topRatedTV()
                try? await Task.sleep(for: .seconds(1))
                try await tmdbManager.topRatedMovie()
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}
