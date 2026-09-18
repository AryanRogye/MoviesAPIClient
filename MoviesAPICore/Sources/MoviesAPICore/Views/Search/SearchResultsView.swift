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

#if DEBUG
#Preview {
    @Previewable @State var tmdbManager: TMDBManager?

    if let tmdbManager {
        NavigationStack {
            SearchResultsView(searchResults: [
                KTSearchResult(
                    id: 969681,
                    mediaType: .movie,
                    title: "Spider-Man: Brand New Day",
                    name: nil,
                    posterPath: "/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg",
                    overview: """
                    Fighting crime full-time as Spider-Man in a world that doesn't remember him—and the pressure of seeing his old friends move on without him—sparks a change in Peter Parker he may not have the power to control.
                    """,
                    releaseDate: "2026-07-31",
                    firstAirDate: nil
                ),
                KTSearchResult(
                    id: 38867,
                    mediaType: .tv,
                    title: nil,
                    name: "Lab Rats",
                    posterPath: "/lcQMvn9ZptPd3dxn0a17viRfi7Y.jpg",
                    overview: """
                    Leo discovers three superhuman teenagers living in a secret underground lab beneath his new home.
                    """,
                    releaseDate: nil,
                    firstAirDate: "2012-02-27"
                )
            ])
            .environment(tmdbManager)
            .environment(PlaybackSession())
            .environment(BlockingService())
            .modelContainer(
                for: [Favorite.self, History.self, Collection.self],
                inMemory: true
            )
        }
    } else {
        ProgressView()
            .task {
                do {
                    tmdbManager = try .init(
                        tmdbClient: TMDBClientPreview(),
                        token: "preview"
                    )
                } catch {
                    print(error.localizedDescription)
                }
            }
    }

}
#endif
