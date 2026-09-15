//
//  SearchResultsView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import SwiftData

struct SearchResultsView: View {

    @Environment(\.modelContext) var modelContext
    @Query var favorites: [Favorite]
    let searchResults: [SearchResult]

    var body: some View {
        ForEach(searchResults, id: \.id) { result in
            NavigationLink {
                WatchDetailView(result: result)
            } label: {
                SearchResultsRow(result: result)
                    .contextMenu {
                        contextMenu(result: result)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func contextMenu(result: SearchResult) -> some View {
        let isFavorite = isFavorite(result)
        Button {
            if isFavorite {
                if let favorite = favorites.first(where: { $0.id == result.id }) {
                    modelContext.delete(favorite)
                }
            } else {
                let favorite = Favorite(
                    id: result.id,
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
    }

    func isFavorite(_ result: SearchResult) -> Bool {
        for favorite in favorites {
            if result.id == favorite.id {
                return true
            }
        }
        return false
    }
}
