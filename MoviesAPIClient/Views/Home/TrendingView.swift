//
//  TrendingView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import SwiftUI
import SharedLogic

struct TrendingView: View {

    @Environment(TMDBManager.self) var tmdbManager

    let filter: LibraryFilter
    @Binding var error: String?
    @Binding var showError: Bool

    @State private var isResolving: Bool = false
    @State private var resolveTask: Task<Void, Never>?
    @State private var resolvingTrending: KTTrendingResult?
    @State private var searchResult: KTSearchResult?
    @State private var goToDetail: Bool = false

    let trendingRows: [GridItem] = [
        GridItem(.fixed(180), spacing: 12),
        GridItem(.fixed(180), spacing: 12),
    ]

    var filteredResults: [KTTrendingResult] {
        switch filter {
        case .all:
            tmdbManager.trendingResults
        case .tv:
            tmdbManager.trendingResults.filter { result in
                result.mediaType == .tv
            }
        case .movies:
            tmdbManager.trendingResults.filter { result in
                result.mediaType == .movie
            }
        }
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: trendingRows, spacing: 12) {
                if tmdbManager.trendingResults.isEmpty {
                    ProgressView()
                } else {
                    ForEach(filteredResults, id: \.id) { trending in
                        HomeRow(
                            imagePath: trending.backdropPath,
                            name: trending.name ?? trending.title ?? "",
                            mediaType: trending.mediaType
                        )
                        .onTapGesture {
                            resolve(trending)
                        }
                        .overlay {
                            if resolvingTrending == trending {
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

    private func resolve(_ trending: KTTrendingResult) {
        if isResolving { return }
        resolveTask = Task {

            self.resolvingTrending = trending
            isResolving = true
            defer {
                isResolving = false
                resolvingTrending = nil
            }

            do {
                try await tmdbManager.search(trending.name ?? trending.title ?? "")
                if !tmdbManager.searchResults.isEmpty {
                    if let result = tmdbManager.searchResults.first(where: { $0.id == trending.id }) {
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
