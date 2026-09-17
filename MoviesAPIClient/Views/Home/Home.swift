//
//  Home.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import SwiftUI
import SharedLogic
import SwiftData

struct Home: View {

    @Environment(TMDBManager.self) var tmdbManager

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var selectedFilter: LibraryFilter = .all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Trending")
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .padding(.top, 8)
                TrendingView(
                    filter: selectedFilter,
                    error: $error,
                    showError: $showError
                )

                Text("Now Playing Movies")
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .padding(.top, 8)
                KTMoviesView(
                    movies: tmdbManager.nowPlayingMovies,
                    error: $error,
                    showError: $showError
                )

                Text("Popular TV Shows")
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .padding(.top, 8)
                KTTVView(
                    tv: tmdbManager.popularTV,
                    error: $error,
                    showError: $showError
                )

                Text("Popular Movies")
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .padding(.top, 8)
                KTMoviesView(
                    movies: tmdbManager.popularMovies,
                    error: $error,
                    showError: $showError
                )

                Text("Top Rated TV Shows")
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .padding(.top, 8)
                KTTVView(
                    tv: tmdbManager.topRatedTV,
                    error: $error,
                    showError: $showError
                )

                Text("Top Rated Movies")
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .padding(.top, 8)
                KTMoviesView(
                    movies: tmdbManager.topRatedMovies,
                    error: $error,
                    showError: $showError
                )
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
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("", selection: $selectedFilter) {
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
