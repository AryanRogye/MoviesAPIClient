//
//  TVDetailView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

struct TVDetailView: View {

    let result: SearchResult
    @Environment(TMDBManager.self) var tmdbManager

    @State private var error: String?
    @State private var showError: Bool = false

    let seasonColumns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    let showColumns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    @State private var tvShow: TVShow?
    @State private var selectedSeasonNumber: Int? = nil

    @State private var loadSeasonTask: Task<Void, Never>?
    @State private var isLoadingSeason = false

    @State private var seasonInfo: SeasonInfo?
    @State private var selectedEpisode: Episode? = nil

    @State private var tvUrl: URL?
    @State private var reloadID = UUID()

    var body: some View {
        ScrollView {
            if let tvUrl {
                EmbeddedMovieView(url: tvUrl)
                    .id(reloadID)
                    .frame(width: UIScreen.main.bounds.width - 20, height: 200)
            }

            if let tvShow {
                LazyVGrid(columns: seasonColumns, spacing: 16) {
                    ForEach(tvShow.seasons, id: \.id) { season in
                        Text("Season \(season.seasonNumber)")
                            .padding(8)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedSeasonNumber == season.seasonNumber ? .yellow : .clear)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(
                                                .yellow,
                                                style: .init(lineWidth: 1)
                                            )
                                    }
                            }
                            .onTapGesture {
                                guard !isLoadingSeason else { return }
                                selectedSeasonNumber = season.seasonNumber
                            }
                    }
                }
            }

            if let seasonInfo {
                LazyVGrid(columns: showColumns, spacing: 16) {
                    ForEach(seasonInfo.episodes, id: \.id)  { episode in
                        Text("Episode \(episode.episodeNumber)")
                            .padding(8)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedEpisode == episode ? .yellow : .clear)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(
                                                .yellow,
                                                style: .init(lineWidth: 1)
                                            )
                                    }
                            }
                            .onTapGesture {
                                selectedEpisode = episode
                            }
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
        .onChange(of: selectedEpisode) { _, newValue in
            if let newValue, let selectedSeasonNumber {
                loadTVShow(season: selectedSeasonNumber, episode: newValue.episodeNumber)
            }
        }
        .onChange(of: selectedSeasonNumber) { _, newValue in
            if let newValue {
                seasonInfo = nil
                selectedEpisode = nil
                loadSeason(season: newValue)
            }
        }
        .toolbar {
            if let tvUrl {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        reloadID = UUID()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            do {
                tvShow = try await tmdbManager.infoOnTV(for: result.id)
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }

    private func loadTVShow(season: Int, episode: Int) {
        let tmdb_show_id = result.id

        do {
            tvUrl = try MoviesAPILoader.loadTvShow(showId: tmdb_show_id, season: season, episode: episode)
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    private func loadSeason(season: Int) {
        if isLoadingSeason { return }
        loadSeasonTask = Task {
            isLoadingSeason = true
            defer { isLoadingSeason = false }
            do {
                seasonInfo = try await tmdbManager.seasonInfo(for: result.id, seasonNumber: season)
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}
