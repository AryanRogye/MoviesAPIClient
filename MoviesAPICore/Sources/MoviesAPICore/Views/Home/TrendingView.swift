//
//  TrendingView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import SwiftUI
import SwiftData

struct TrendingView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) var playbackSession
    @Environment(\.modelContext) var modelContext
    @Query var favorites: [Favorite]
    @Query var collections: [Collection]

    let filter: LibraryFilter
    @Binding var error: String?
    @Binding var showError: Bool

    @State private var isResolving: Bool = false
    @State private var resolveTask: Task<Void, Never>?
    @State private var resolvingTrending: KTTrendingResult?
    @State private var searchResult: KTSearchResult?
    @State private var goToDetail: Bool = false

    let trendingRows: [GridItem] = [
        GridItem(.fixed(180), spacing: 12),
        GridItem(.fixed(180), spacing: 12),
    ]

    @State private var showCreateCollection: Bool = false
    @State private var collectionName: String = ""
    @State private var collectionResultToAdd: KTTrendingResult?

    var filteredResults: [KTTrendingResult] {
        switch filter {
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

    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: trendingRows, spacing: 12) {
                if tmdbManager.trendingResults.isEmpty {
                    ProgressView()
                } else {
                    ForEach(filteredResults, id: \.id) { trending in
                        HomeRow(
                            imagePath: trending.backdropPath,
                            name: trending.name ?? trending.title ?? "",
                            mediaType: trending.mediaType
                        )
                        .contextMenu {
                            contextMenu(result: trending)
                        }
                        .onTapGesture {
                            playbackSession.stop()
                            resolve(trending)
                        }
                        .overlay {
                            if resolvingTrending == trending {
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
        .alert("Create Collection", isPresented: $showCreateCollection) {
            TextField("Collection Name", text: $collectionName)

            Button("Cancel", role: .cancel) {
                collectionName = ""
                collectionResultToAdd = nil
            }

            Button("Create") {
                guard
                    !collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    let result = collectionResultToAdd
                        else { return }

                let item = CollectionItem(
                    resultId: Int(result.id),
                    name: result.name ?? result.title ?? "",
                    mediaType: result.mediaType.rawValue,
                    posterPath: result.posterPath
                )

                let collection = Collection(
                    name: collectionName.trimmingCharacters(in: .whitespacesAndNewlines),
                    results: [item]
                )

                modelContext.insert(collection)

                collectionName = ""
                collectionResultToAdd = nil
            }
        } message: {
            Text("Enter a name for your new collection.")
        }
    }

    @ViewBuilder
    private func contextMenu(result: KTTrendingResult) -> some View {
        let isFavorite = isFavorite(result)
        Button {
            if isFavorite {
                if let favorite = favorites.first(where: { $0.id == result.id }) {
                    modelContext.delete(favorite)
                }
            } else {
                let favorite = Favorite(
                    id: Int(result.id),
                    name: result.name ?? result.title ?? "",
                    mediaType: result.mediaType.rawValue,
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

        Menu {
            ForEach(collections) { collection in
                let inCollection = isInCollection(result, collection: collection)
                Button {
                    if inCollection {
                        collection.results.removeAll(where: {
                            $0.resultId == result.id && $0.mediaType == KTMediaType.movie.rawValue
                        })
                    } else {
                        collection.results.append(CollectionItem(
                            resultId: Int(result.id),
                            name: result.name ?? result.title ?? "",
                            mediaType: result.mediaType.rawValue,
                            posterPath: result.posterPath
                        ))
                    }
                } label: {
                    Label(
                        collection.name,
                        systemImage: inCollection ? "checkmark" : "rectangle.stack"
                    )
                }
            }
            Button {
                showCreateCollection = true
                collectionName = ""
                collectionResultToAdd = result
            } label: {
                Label(
                    "New Collection",
                    systemImage: "plus"
                )
            }
        } label: {
            Label("Add To Collection", systemImage: "rectangle.stack.badge.plus")
        }

    }

    func isInCollection(
        _ result: KTTrendingResult,
        collection: Collection
    ) -> Bool {
        collection.results.contains {
            $0.resultId == result.id &&
            $0.mediaType == result.mediaType.rawValue
        }
    }

    func isFavorite(_ result: KTTrendingResult) -> Bool {
        for favorite in favorites {
            if result.id == favorite.id && result.mediaType.rawValue == favorite.mediaType {
                return true
            }
        }
        return false
    }

    private func resolve(_ trending: KTTrendingResult) {
        if isResolving { return }
        resolveTask = Task {

            self.resolvingTrending = trending
            isResolving = true
            defer {
                isResolving = false
                resolvingTrending = nil
            }

            do {
                try await tmdbManager.search(trending.name ?? trending.title ?? "")
                if !tmdbManager.searchResults.isEmpty {
                    if let result = tmdbManager.searchResults.first(where: { $0.id == trending.id }) {
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
