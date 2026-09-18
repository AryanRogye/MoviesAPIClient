//
//  HomeListView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/18/26.
//

import SwiftUI
import SwiftData

struct HomeListView<Media: MediaListItem>: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) var playbackSession
    @Environment(\.modelContext) var modelContext
    @Query var favorites: [Favorite]
    @Query var collections: [Collection]

    let contents: [Media]
    @Binding var error: String?
    @Binding var showError: Bool

    @State private var isResolving: Bool = false
    @State private var resolveTask: Task<Void, Never>?
    @State private var resolvingMedia: Media?
    @State private var searchResult: KTSearchResult?
    @State private var goToDetail: Bool = false

    let popularTVRows: [GridItem] = [
        GridItem(.fixed(180), spacing: 12),
        GridItem(.fixed(180), spacing: 12),
    ]

    @State private var showCreateCollection: Bool = false
    @State private var collectionName: String = ""
    @State private var collectionResultToAdd: Media?


    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: popularTVRows, spacing: 12) {
                if contents.isEmpty {
                    ProgressView()
                } else {
                    ForEach(contents, id: \.id) { content in
                        HomeRow(
                            imagePath: content.backdropPath,
                            name: content.displayName,
                            mediaType: content.mediaType
                        )
                        .contextMenu {
                            contextMenu(result: content)
                        }
                        .onTapGesture {
                            playbackSession.stop()
                            resolve(content)
                        }
                        .overlay {
                            if resolvingMedia?.id == content.id && resolvingMedia?.mediaType == content.mediaType {
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
                    name: result.displayName,
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
    private func contextMenu(result: Media) -> some View {
        let isFavorite = isFavorite(result)
        Button {
            if isFavorite {
                if let favorite = favorites.first(where: { $0.id == result.id }) {
                    modelContext.delete(favorite)
                }
            } else {
                let favorite = Favorite(
                    id: Int(result.id),
                    name: result.displayName,
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
                            $0.resultId == result.id && $0.mediaType == result.mediaType.rawValue
                        })
                    } else {
                        collection.results.append(CollectionItem(
                            resultId: Int(result.id),
                            name: result.displayName,
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
        _ result: Media,
        collection: Collection
    ) -> Bool {
        collection.results.contains {
            $0.resultId == result.id &&
            $0.mediaType == result.mediaType.rawValue
        }
    }

    func isFavorite(_ result: Media) -> Bool {
        for favorite in favorites {
            if result.id == favorite.id && favorite.mediaType == result.mediaType.rawValue {
                return true
            }
        }
        return false
    }

    private func resolve(_ result: Media) {
        if isResolving { return }
        resolveTask = Task {

            self.resolvingMedia = result
            isResolving = true
            defer {
                isResolving = false
                resolvingMedia = nil
            }

            do {
                try await tmdbManager.search(result.displayName)
                if !tmdbManager.searchResults.isEmpty {
                    if let result = tmdbManager.searchResults.first(where: { $0.id == result.id }) {
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
