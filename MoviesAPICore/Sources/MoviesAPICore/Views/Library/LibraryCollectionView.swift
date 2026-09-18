//
//  LibraryCollectionView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/18/26.
//

import SwiftUI
import SwiftData

struct LibraryCollectionView: View {
    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) var playbackSession

    @Query var favorites: [Favorite]
    @Query var collection: [Collection]

    let rows: [GridItem] = [
        GridItem(.fixed(180), spacing: 12),
        GridItem(.fixed(180), spacing: 12),
    ]

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var searchResult: KTSearchResult?
    @State private var goToDetail: Bool = false

    @State private var resolveTask: Task<Void, Never>?
    @State private var resolvingFavorite: Favorite?
    @State private var isResolving: Bool = false

    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows,spacing: 12) {
                ForEach(collection, id: \.id) { collection in
                    Text(collection.name)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .navigationDestination(isPresented: $goToDetail) {
            if let searchResult {
                WatchDetailView(result: searchResult)
            }
        }
        .onDisappear {
            resolveTask?.cancel()
            resolveTask = nil
        }
    }
}
