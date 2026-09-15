//
//  Home.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import SwiftData

enum LibraryFilter: String, CaseIterable {
    case all = "All"
    case tv = "TV"
    case movies = "Movies"

    var mediaType: MediaType? {
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

struct Home: View {

    @Environment(\.modelContext) var modelContext
    @Query var favorites: [Favorite]

    @State private var selectedFilter: LibraryFilter = .all

    var body: some View {
        ScrollView {
            if favorites.isEmpty {
                emptyView
            } else {
                FavoritesView(filter: selectedFilter)
            }
        }
        .navigationTitle("Home")
        .onChange(of: selectedFilter) { _, newValue in
            
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("", selection: $selectedFilter) {
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
