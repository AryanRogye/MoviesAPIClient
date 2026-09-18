//
//  SearchTab.swift
//  MoviesAPIClient
//

import SwiftUI

public struct SearchTab: View {

    @Environment(TMDBManager.self) private var tmdbManager

    public init() {}

    public var body: some View {
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
