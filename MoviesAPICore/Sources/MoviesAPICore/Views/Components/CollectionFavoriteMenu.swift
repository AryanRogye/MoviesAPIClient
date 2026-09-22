//
//  CollectionFavoriteMenu.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/22/26.
//

import SwiftUI
import SwiftData

struct CollectionFavoriteMenu: View {

    @Environment(\.modelContext) var modelContext

    let result: KTSearchResult
    @Binding var showCreateCollection: Bool
    @Binding var collectionName: String
    @Binding var collectionResultToAdd: KTSearchResult?

    @Query var favorites: [Favorite]
    @Query var collections: [Collection]

    var body: some View {
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
