//
//  FavoritesView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/15/26.
//

import SwiftUI
import SwiftData

struct FavoritesView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) var playbackSession
    @Query var favorites: [Favorite]

    let filter: LibraryFilter

    @State private var showCreateCollection: Bool = false
    @State private var collectionName: String = ""
    @State private var collectionResultToAdd: Favorite?

    var filteredFavorites: [Favorite] {
        switch filter {
        case .all:
            return favorites
        case .tv:
            return favorites.filter { favorite in
                return favorite.mediaType == "tv"
            }
        case .movies:
            return favorites.filter { favorite in
                return favorite.mediaType == "movie"
            }
        }
    }

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
                ForEach(filteredFavorites, id: \.id) { favorite in
                    FavoriteRow(
                        favorite: favorite,
                        showCreateCollection: $showCreateCollection,
                        collectionName: $collectionName,
                        collectionResultToAdd: $collectionResultToAdd
                    )
                    .onTapGesture {
                        playbackSession.stop()
                        resolve(favorite)
                    }
                    .overlay {
                        if resolvingFavorite == favorite {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.black.opacity(0.1))
                        }
                    }
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
                    name: result.name ?? "",
                    mediaType: result.mediaType,
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

    private func resolve(_ favorite: Favorite) {
        if isResolving { return }
        resolveTask = Task {

            self.resolvingFavorite = favorite
            isResolving = true
            defer {
                isResolving = false
                resolvingFavorite = nil
            }

            do {
                try await tmdbManager.search(favorite.name)
                if !tmdbManager.searchResults.isEmpty {
                    if let result = tmdbManager.searchResults.first(where: { $0.id == favorite.id }) {
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

struct FavoriteRow: View {

    @Environment(\.modelContext) var modelContext
    let favorite: Favorite
    @Query var collections: [Collection]

    @Binding var showCreateCollection: Bool
    @Binding var collectionName: String
    @Binding var collectionResultToAdd: Favorite?

    var body: some View {
        VStack(alignment: .leading) {
            FavoriteImageView(favorite: favorite)
                .frame(width: 110, height: 165)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(favorite.name)
                .font(.subheadline.weight(.medium))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 110, height: 165)
        .overlay(alignment: .topTrailing) {
            Text(favorite.mediaType == "tv" ? "TV" : "Movie")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.6), in: Capsule())
                .foregroundStyle(.white)
                .padding(6)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                modelContext.delete(favorite)
            } label: {
                Label("Unfavorite", systemImage: "star.slash.fill")
            }
            Menu {
                ForEach(collections) { collection in
                    let inCollection = isInCollection(favorite, collection: collection)
                    Button {
                        if inCollection {
                            collection.results.removeAll(where: {
                                $0.resultId == favorite.id && $0.mediaType == favorite.mediaType
                            })
                        } else {
                            collection.results.append(CollectionItem(
                                resultId: Int(favorite.id),
                                name: favorite.name ?? "",
                                mediaType: favorite.mediaType,
                                posterPath: favorite.posterPath
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
                    collectionResultToAdd = favorite
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
    }

    func isInCollection(
        _ result: Favorite,
        collection: Collection
    ) -> Bool {
        collection.results.contains {
            $0.resultId == result.id &&
            $0.mediaType == result.mediaType
        }
    }
}

private struct FavoriteImageView: View {

    let favorite: Favorite

    var imagePath: String? {
        favorite.posterPath
    }

    var body: some View {
        Group {
            if let posterPath = imagePath,
               let url = URL(
                string: "https://image.tmdb.org/t/p/w500\(posterPath)"
               ) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                        .aspectRatio(2/3, contentMode: .fit)
                        .overlay(ProgressView())
                }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()
            } else {
                ZStack {
                    Rectangle()
                        .fill(.quaternary)

                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .clipped()
            }
        }
    }
}
