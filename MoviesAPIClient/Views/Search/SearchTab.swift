//
//  SearchTab.swift
//  MoviesAPIClient
//

import SwiftUI

struct SearchTab: View {

    @Environment(TMDBManager.self) private var tmdbManager

    var body: some View {
        ScrollView {
            if tmdbManager.searchResults.isEmpty {
                ContentUnavailableView.search
            } else {
                SearchResultsView(searchResults: tmdbManager.searchResults)
            }
        }
        .navigationTitle("Search")
    }
}
