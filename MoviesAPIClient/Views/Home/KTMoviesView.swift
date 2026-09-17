//
//  KTMoviesView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import SwiftUI
import SwiftData
import SharedLogic

struct KTMoviesView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) var playbackSession
    @Environment(\.modelContext) var modelContext
    @Query var favorites: [Favorite]

    let movies: [KTMovieListResult]
    @Binding var error: String?
    @Binding var showError: Bool

    @State private var isResolving: Bool = false
    @State private var resolveTask: Task<Void, Never>?
    @State private var resolvingPopularMovie: KTMovieListResult?
    @State private var searchResult: KTSearchResult?
    @State private var goToDetail: Bool = false

    let popularTVRows: [GridItem] = [
        GridItem(.fixed(180), spacing: 12),
        GridItem(.fixed(180), spacing: 12),
    ]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: popularTVRows, spacing: 12) {
                if movies.isEmpty {
                    ProgressView()
                } else {
                    ForEach(movies, id: \.id) { popularMovie in
                        HomeRow(
                            imagePath: popularMovie.backdropPath,
                            name: popularMovie.title,
                            mediaType: .movie
                        )
                        .contextMenu {
                            contextMenu(result: popularMovie)
                        }
                        .onTapGesture {
                            playbackSession.stop()
                            resolve(popularMovie)
                        }
                        .overlay {
                            if resolvingPopularMovie == popularMovie {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(.black.opacity(0.1))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .navigationDestination(isPresented: $goToDetail) {
            if let searchResult {
                WatchDetailView(result: searchResult)
            }
        }
    }

    @ViewBuilder
    private func contextMenu(result: KTMovieListResult) -> some View {
        let isFavorite = isFavorite(result)
        Button {
            if isFavorite {
                if let favorite = favorites.first(where: { $0.id == result.id }) {
                    modelContext.delete(favorite)
                }
            } else {
                let favorite = Favorite(
                    id: Int(result.id),
                    name: result.title,
                    mediaType: KTMediaType.movie.rawValue,
                    posterPath: result.posterPath
                )
                modelContext.insert(favorite)
            }
        } label: {
            Label(
                isFavorite ? "Unfavorite" : "Favorite",
                systemImage: isFavorite ? "star.slash.fill" : "star.fill"
            )
        }
    }

    func isFavorite(_ result: KTMovieListResult) -> Bool {
        for favorite in favorites {
            if result.id == favorite.id && favorite.mediaType == KTMediaType.movie.rawValue {
                return true
            }
        }
        return false
    }

    private func resolve(_ popularMovie: KTMovieListResult) {
        if isResolving { return }
        resolveTask = Task {

            self.resolvingPopularMovie = popularMovie
            isResolving = true
            defer {
                isResolving = false
                resolvingPopularMovie = nil
            }

            do {
                try await tmdbManager.search(popularMovie.title)
                if !tmdbManager.searchResults.isEmpty {
                    if let result = tmdbManager.searchResults.first(where: { $0.id == popularMovie.id }) {
                        self.searchResult = result
                        self.goToDetail = true
                    }
                    /// Clear once we finish
                    tmdbManager.clearSearchResults()
                }
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}
