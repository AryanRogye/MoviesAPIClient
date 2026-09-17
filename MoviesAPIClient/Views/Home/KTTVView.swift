//
//  KTTVView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import SwiftUI
import SwiftData
import MoviesAPICore

struct KTTVView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) var playbackSession
    @Environment(\.modelContext) var modelContext
    @Query var favorites: [Favorite]

    let tv: [KTTVListResult]
    @Binding var error: String?
    @Binding var showError: Bool

    @State private var isResolving: Bool = false
    @State private var resolveTask: Task<Void, Never>?
    @State private var resolvingPopularTV: KTTVListResult?
    @State private var searchResult: KTSearchResult?
    @State private var goToDetail: Bool = false

    let popularTVRows: [GridItem] = [
        GridItem(.fixed(180), spacing: 12),
        GridItem(.fixed(180), spacing: 12),
    ]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: popularTVRows, spacing: 12) {
                if tv.isEmpty {
                    ProgressView()
                } else {
                    ForEach(tv, id: \.id) { popularTV in
                        HomeRow(
                            imagePath: popularTV.backdropPath,
                            name: popularTV.name,
                            mediaType: .tv
                        )
                        .contextMenu {
                            contextMenu(result: popularTV)
                        }
                        .onTapGesture {
                            playbackSession.stop()
                            resolve(popularTV)
                        }
                        .overlay {
                            if resolvingPopularTV == popularTV {
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
    private func contextMenu(result: KTTVListResult) -> some View {
        let isFavorite = isFavorite(result)
        Button {
            if isFavorite {
                if let favorite = favorites.first(where: { $0.id == result.id }) {
                    modelContext.delete(favorite)
                }
            } else {
                let favorite = Favorite(
                    id: Int(result.id),
                    name: result.name,
                    mediaType: KTMediaType.tv.rawValue,
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

    func isFavorite(_ result: KTTVListResult) -> Bool {
        for favorite in favorites {
            if result.id == favorite.id && favorite.mediaType == KTMediaType.tv.rawValue {
                return true
            }
        }
        return false
    }


    private func resolve(_ popularTV: KTTVListResult) {
        if isResolving { return }
        resolveTask = Task {

            self.resolvingPopularTV = popularTV
            isResolving = true
            defer {
                isResolving = false
                resolvingPopularTV = nil
            }

            do {
                try await tmdbManager.search(popularTV.name)
                if !tmdbManager.searchResults.isEmpty {
                    if let result = tmdbManager.searchResults.first(where: { $0.id == popularTV.id }) {
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
