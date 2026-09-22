//
//  HistoryView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/15/26.
//

import SwiftUI
import SwiftData

public struct HistoryView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(BlockingService.self) var blockingService
    @Environment(PlaybackSession.self) var playbackSession

    @Environment(\.modelContext) var modelContext

    @Query(sort: \History.watchedAt, order: .reverse)
    var history: [History]

    @State private var searchResult: KTSearchResult?
    @State private var resolveTask: Task<Void, Never>?
    @State private var selectedHistory: History?
    @State private var resolvingHistory: History?
    @State private var isResolving: Bool = false
    @State private var goToDetail: Bool = false

    @State private var error: String?
    @State private var showError: Bool = false

    public init() {}

    @AppStorage("DisplayServer") private var displayServerRawValue = KTDisplayServer.moviesApi.rawValue

    private var displayServer: KTDisplayServer {
        KTDisplayServer.entries.first { $0.rawValue == displayServerRawValue } ?? .moviesApi
    }

    private var displayServerBinding: Binding<KTDisplayServer> {
        Binding(
            get: { displayServer },
            set: { displayServerRawValue = $0.rawValue }
        )
    }

    public var body: some View {
        Group {
            if history.isEmpty {
                emptyView
            } else {
                ScrollView {
                    ForEach(history, id: \.id) { item in
                        HistoryRow(history: item)
                            .onTapGesture {
                                playbackSession.stop()
                                resolve(item)
                            }
                            .overlay {
                                if resolvingHistory == item {
                                    ProgressView()
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(.black.opacity(0.1))
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(item)
                                } label: {
                                    Label(
                                        "Remove",
                                        systemImage: "trash"
                                    )
                                }
                            }
                    }
                }
                .alert(isPresented: $showError) {
                    Alert(
                        title: Text("Error"),
                        message: Text("\(error, default: "Unknown Error")")
                    )
                }
                .navigationDestination(isPresented: $goToDetail, destination: {
                    if let selectedHistory, let searchResult {
                        switch selectedHistory.mediaType {
                        case .episode:
                            if let season = selectedHistory.season, let episode = selectedHistory.episode {
                                TVDetailView(
                                    displayServer: displayServerBinding,
                                    result: searchResult,
                                    seasonNumber: season,
                                    episodeNumber: episode
                                )
                                .environment(tmdbManager)
                                .environment(blockingService)
                            }
                        case .movie:
                                MovieDetailView(
                                    displayServer: displayServerBinding,
                                    result: searchResult
                                )
                                .environment(tmdbManager)
                                .environment(blockingService)
                        }
                    }
                })
                .onAppear {
                    /// if we come back
                    self.selectedHistory = nil
                    self.searchResult = nil
                    self.goToDetail = false
                    self.resolvingHistory = nil
                }
                .onDisappear {
                    resolveTask?.cancel()
                    resolveTask = nil
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
#if os(macOS)
            ToolbarSpacer(.flexible)
#endif
        }
    }

    private var emptyView: some View {
        ContentUnavailableView(
            "No Watch History",
            systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
            description: Text("Movies and episodes you watch will show up here.")
        )
    }

    private func resolve(_ history: History) {
        if isResolving { return }

        resolveTask = Task {
            resolvingHistory = history
            isResolving = true

            defer {
                isResolving = false
                resolvingHistory = nil
            }

            do {
                try await tmdbManager.search(history.name)

                if let result = tmdbManager.searchResults.first(
                    where: { $0.id == history.resultId }
                ) {
                    searchResult = result
                    selectedHistory = history
                    goToDetail = true
                }

                tmdbManager.clearSearchResults()
            } catch {
                self.error = error.localizedDescription
                showError = true
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(history[index])
        }
    }
}
