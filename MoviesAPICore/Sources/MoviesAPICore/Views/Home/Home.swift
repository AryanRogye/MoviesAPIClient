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
    @Environment(\.modelContext) var modelContext

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

    @AppStorage("home.trendingExpanded")
    private var trendingExpanded = true

    @AppStorage("home.nowPlayingMoviesExpanded")
    private var nowPlayingMoviesExpanded = true

    @AppStorage("home.popularTVExpanded")
    private var popularTVExpanded = true

    @AppStorage("home.popularMoviesExpanded")
    private var popularMoviesExpanded = true

    @AppStorage("home.topRatedTVExpanded")
    private var topRatedTVExpanded = true

    @AppStorage("home.topRatedMoviesExpanded")
    private var topRatedMoviesExpanded = true

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup(isExpanded: $trendingExpanded) {
                    HomeListView(
                        contents: filteredResults,
                        error: $error,
                        showError: $showError
                    )
                } label: {
                    Text("Trending All Day")
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                if selectedFilter == .movies || selectedFilter == .all {
                    DisclosureGroup(isExpanded: $nowPlayingMoviesExpanded) {
                        HomeListView(
                            contents: tmdbManager.nowPlayingMovies,
                            error: $error,
                            showError: $showError
                        )
                    } label: {
                        Text("Now Playing Movies")
                            .font(.title2.bold())
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                }

                if selectedFilter == .tv || selectedFilter == .all {
                    DisclosureGroup(isExpanded: $popularTVExpanded) {
                        HomeListView(
                            contents: tmdbManager.popularTV,
                            error: $error,
                            showError: $showError
                        )
                    } label: {
                        Text("Popular TV Shows")
                            .font(.title2.bold())
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                }

                if selectedFilter == .movies || selectedFilter == .all {
                    DisclosureGroup(isExpanded: $popularMoviesExpanded) {
                        HomeListView(
                            contents: tmdbManager.popularMovies,
                            error: $error,
                            showError: $showError
                        )
                    } label: {
                        Text("Popular Movies")
                            .font(.title2.bold())
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                }

                if selectedFilter == .tv || selectedFilter == .all {
                    DisclosureGroup(isExpanded: $topRatedTVExpanded) {
                        HomeListView(
                            contents: tmdbManager.topRatedTV,
                            error: $error,
                            showError: $showError
                        )
                    } label: {
                        Text("Top Rated TV Shows")
                            .font(.title2.bold())
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                }

                if selectedFilter == .movies || selectedFilter == .all {
                    DisclosureGroup(isExpanded: $topRatedMoviesExpanded) {
                        HomeListView(
                            contents: tmdbManager.topRatedMovies,
                            error: $error,
                            showError: $showError
                        )
                    } label: {
                        Text("Top Rated Movies")
                            .font(.title2.bold())
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
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
//            do {
//                try modelContext.delete(model: Collection.self)
//                try modelContext.delete(model: CollectionItem.self)
//                try modelContext.save()
//                print("Deleted Models")
//            } catch {
//                print("Failed to delete all YourModel objects: \(error)")
//            }
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
