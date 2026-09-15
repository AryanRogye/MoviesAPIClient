//
//  Home.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

struct Home: View {

    @State private var searchText: String = ""
    @Environment(TMDBManager.self) var tmdbManager

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching: Bool = false

    var body: some View {
        ScrollView {
            if tmdbManager.searchResults.isEmpty {
                Text("Home Screen")
            } else {
                SearchResultsView(searchResults: tmdbManager.searchResults)
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .navigationTitle(tmdbManager.searchResults.isEmpty ? "Home" : "Results")
        .searchable(text: $searchText, prompt: "Search")
        .onSubmit(of: .search) {
            search()
        }
        .toolbar {
            if !tmdbManager.searchResults.isEmpty {
                ToolbarItem(placement: .navigation) {
                    Button(action: tmdbManager.clearSearchResults) {
                        Image(systemName: "chevron.backward")
                    }
                }
            }
        }
    }

    private func search() {
        if isSearching { return }
        searchTask = Task {
            isSearching = true
            defer { isSearching = false }
            do {
                try await tmdbManager.search(searchText)
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}
