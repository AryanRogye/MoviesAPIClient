//
//  SearchResultsView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import SwiftData
import SharedLogic

struct SearchResultsView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(PlaybackSession.self) var playbackSession
    @Query var favorites: [Favorite]
    @Query var collections: [Collection]
    let searchResults: [KTSearchResult]

    @State private var selectedResult: KTSearchResult?
    @State private var showDetail = false

    @State private var showCreateCollection: Bool = false
    @State private var collectionName: String = ""
    @State private var collectionResultToAdd: KTSearchResult?

    var body: some View {
        ForEach(searchResults, id: \.id) { result in
            SearchResultsRow(result: result)
                .contextMenu {
                    contextMenu(result: result)
                }
                .contentShape(.rect)
                .onTapGesture {
                    playbackSession.stop()
                    selectedResult = result
                    showDetail = true
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
                    name: result.title ?? result.name ?? "",
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
        .navigationDestination(isPresented: $showDetail) {
            if let selectedResult {
                WatchDetailView(result: selectedResult)
            }
        }
    }

    @ViewBuilder
    private func contextMenu(result: KTSearchResult) -> some View {
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
                Label(
                    collection.name,
                    systemImage: inCollection ? "checkmark" : "rectangle.stack"
                )
                .onTapGesture {
                    if inCollection {
                        collection.results.removeAll(where: {
                            $0.resultId == result.id && $0.mediaType == result.mediaType.rawValue
                        })
                    } else {
                        collection.results.append(CollectionItem(
                            resultId: Int(result.id),
                            name: result.title ?? result.name ?? "",
                            mediaType: result.mediaType.rawValue,
                            posterPath: result.posterPath
                        ))
                    }
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
        _ result: KTSearchResult,
        collection: Collection
    ) -> Bool {
        collection.results.contains {
            $0.resultId == result.id &&
            $0.mediaType == result.mediaType.rawValue
        }
    }

    func isFavorite(_ result: KTSearchResult) -> Bool {
        for favorite in favorites {
            if result.id == favorite.id && favorite.mediaType == result.mediaType.rawValue {
                return true
            }
        }
        return false
    }
}
