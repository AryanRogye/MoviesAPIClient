//
//  KTTVView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import SwiftUI
import SwiftData

struct KTTVView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) var playbackSession
    @Environment(\.modelContext) var modelContext
    @Query var favorites: [Favorite]
    @Query var collections: [Collection]

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

    @State private var showCreateCollection: Bool = false
    @State private var collectionName: String = ""
    @State private var collectionResultToAdd: KTTVListResult?

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
                    name: result.name,
                    mediaType: KTMediaType.tv.rawValue,
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
                            name: result.name,
                            mediaType: KTMediaType.tv.rawValue,
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
        _ result: KTTVListResult,
        collection: Collection
    ) -> Bool {
        collection.results.contains {
            $0.resultId == result.id &&
            $0.mediaType == KTMediaType.tv.rawValue
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
