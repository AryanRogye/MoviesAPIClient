//
//  Library.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import SwiftData

public enum LibraryFilter: String, CaseIterable {
    case all = "All"
    case tv = "TV"
    case movies = "Movies"

    var mediaType: KTMediaType? {
        switch self {
        case .all:
            return nil
        case .tv:
            return .tv
        case .movies:
            return .movie
        }
    }
}

public struct Library: View {

    @Environment(\.modelContext) var modelContext
    @Query var favorites: [Favorite]

    @State private var selectedFilter: LibraryFilter = .all

    public init() {}

    public var body: some View {
        ScrollView {
            if favorites.isEmpty {
                emptyView
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Favorites")
                        .font(.title2.bold())
                        .padding(.horizontal)
                        .padding(.top, 8)

                    FavoritesView(filter: selectedFilter)

                    Text("Collection")
                        .font(.title2.bold())
                        .padding(.horizontal)
                    LibraryCollectionView()
                }
                .padding(.bottom)
            }
        }
        .navigationTitle("Library")
        .onChange(of: selectedFilter) { _, newValue in
            
        }
        .toolbar {
#if os(macOS)
            ToolbarSpacer(.flexible)
#endif

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(LibraryFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                } label: {
                    Image(systemName: "line.horizontal.3.decrease")
                }
            }
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No Favorites Yet",
            systemImage: "heart.slash",
            description: Text("Movies and shows you favorite will show up here.")
        )
    }
}
