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
    let searchResults: [KTSearchResult]

    @State private var selectedResult: KTSearchResult?
    @State private var showDetail = false

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
    }

    func isFavorite(_ result: KTSearchResult) -> Bool {
        for favorite in favorites {
            if result.id == favorite.id {
                return true
            }
        }
        return false
    }
}
