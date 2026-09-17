//
//  KTTVView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import SwiftUI
import SharedLogic

struct KTTVView: View {

    @Environment(TMDBManager.self) var tmdbManager

    let tv: [KTTVListResult]
    @Binding var error: String?
    @Binding var showError: Bool

    @State private var isResolving: Bool = false
    @State private var resolveTask: Task<Void, Never>?
    @State private var resolvingPopularTV: KTTVListResult?
    @State private var searchResult: KTSearchResult?
    @State private var goToDetail: Bool = false

    let popularTVRows: [GridItem] = [
        GridItem(.fixed(180), spacing: 12),
        GridItem(.fixed(180), spacing: 12),
    ]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: popularTVRows, spacing: 12) {
                if tv.isEmpty {
                    ProgressView()
                } else {
                    ForEach(tv, id: \.id) { popularTV in
                        HomeRow(
                            imagePath: popularTV.backdropPath,
                            name: popularTV.name,
                            mediaType: .tv
                        )
                        .onTapGesture {
                            resolve(popularTV)
                        }
                        .overlay {
                            if resolvingPopularTV == popularTV {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(.black.opacity(0.1))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .navigationDestination(isPresented: $goToDetail) {
            if let searchResult {
                WatchDetailView(result: searchResult)
            }
        }
    }

    private func resolve(_ popularTV: KTTVListResult) {
        if isResolving { return }
        resolveTask = Task {

            self.resolvingPopularTV = popularTV
            isResolving = true
            defer {
                isResolving = false
                resolvingPopularTV = nil
            }

            do {
                try await tmdbManager.search(popularTV.name)
                if !tmdbManager.searchResults.isEmpty {
                    if let result = tmdbManager.searchResults.first(where: { $0.id == popularTV.id }) {
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
