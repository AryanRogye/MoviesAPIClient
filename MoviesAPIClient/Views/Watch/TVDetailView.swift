//
//  TVDetailView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

struct TVDetailView: View {

    @Binding var displayServer: DisplayServer
    let result: SearchResult
    @Environment(TMDBManager.self) var tmdbManager

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var tvShow: TVShow?
    @State private var selectedSeasonNumber: Int? = nil

    @State private var loadSeasonTask: Task<Void, Never>?
    @State private var isLoadingSeason = false

    @State private var seasonInfo: SeasonInfo?
    @State private var selectedEpisode: Episode? = nil

    @State private var tvUrl: URL?
    @State private var reloadID = UUID()

    @State private var vm = EmbeddedMovieViewModel()

    var body: some View {
        ScrollView {
            if let tvUrl {
#if os(iOS)
                GeometryReader { proxy in
                    EmbeddedMovieView(vm: vm, url: tvUrl)
                        .id(reloadID)
                        .frame(width: proxy.size.width - 20, height: 200)
                }
                .frame(height: 200)
#elseif os(macOS)
                EmbeddedMovieView(url: tvUrl)
                    .id(reloadID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .padding(.horizontal, 10)
#endif
            } else {
                EpisodeImageView(
                    result: result,
                    tvShow: tvShow
                )
            }

            SeasonsView(
                tvShow: tvShow,
                isLoadingSeason: isLoadingSeason,
                selectedSeasonNumber: $selectedSeasonNumber
            )

            EpisodesView(
                seasonInfo: seasonInfo,
                selectedEpisode: $selectedEpisode
            )
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .onChange(of: selectedEpisode) { _, newValue in
            if let newValue, let selectedSeasonNumber {
                self.tvUrl = nil
                reloadID = UUID()
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
        .onChange(of: displayServer) {
            if let selectedSeasonNumber, let selectedEpisode {
                self.tvUrl = nil
                reloadID = UUID()
                loadTVShow(season: selectedSeasonNumber, episode: selectedEpisode.episodeNumber)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("Server", selection: $displayServer) {
                    ForEach(DisplayServer.allCases, id: \.self) { server in
                        Text(server.rawValue)
                            .tag(server)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)

                if tvUrl != nil {
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
            tvUrl = try displayServer.loadTvShow(showId: tmdb_show_id, season: season, episode: episode)
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

private struct EpisodeImageView: View {

    let result: SearchResult
    let tvShow: TVShow?

    var imagePath: String? {
        tvShow?.backdropPath ?? result.posterPath
    }

    var body: some View {
        Group {
            if let posterPath = imagePath,
               let url = URL(
                string: "https://image.tmdb.org/t/p/w500\(posterPath)"
               ) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(maxWidth: .infinity)
                .clipped()
            } else {
                ZStack {
                    Rectangle()
                        .fill(.quaternary)

                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
            }
        }
        .overlay {
            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    .black.opacity(0.15),
                    .black.opacity(0.35),
                    .black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading) {
                Text(result.name ?? "")
                    .fontDesign(.serif)
                    .font(.largeTitle)
                    .fontWeight(.medium)
                Text(result.overview)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }
}

private struct SeasonsView: View {

    let tvShow: TVShow?
    let isLoadingSeason: Bool
    @Binding var selectedSeasonNumber: Int?

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        if let tvShow {
            VStack(alignment: .leading) {
                Text("Seasons")
                    .font(.title2)
                    .fontWeight(.bold)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(tvShow.seasons, id: \.id) { season in
                        Text("Season \(season.seasonNumber)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(
                                selectedSeasonNumber == season.seasonNumber
                                ? .primary
                                : .secondary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background {
                                Capsule()
                                    .fill(
                                        selectedSeasonNumber == season.seasonNumber
                                        ? .white.opacity(0.16)
                                        : .white.opacity(0.06)
                                    )
                            }
                            .onTapGesture {
                                guard !isLoadingSeason else { return }
                                selectedSeasonNumber = season.seasonNumber
                            }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
        }
    }
}

private struct EpisodesView: View {

    let seasonInfo: SeasonInfo?
    @Binding var selectedEpisode: Episode?

    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        if let seasonInfo {
            VStack(alignment: .leading) {
                Text("Episodes")
                    .font(.title2)
                    .fontWeight(.bold)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(seasonInfo.episodes, id: \.id)  { episode in
                        Text("Episode \(episode.episodeNumber)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(
                                selectedEpisode == episode
                                ? .primary
                                : .secondary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background {
                                Capsule()
                                    .fill(
                                        selectedEpisode == episode
                                        ? .white.opacity(0.16)
                                        : .white.opacity(0.06)
                                    )
                            }
                            .onTapGesture {
                                selectedEpisode = episode
                            }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
        }
    }
}

#Preview {
    @Previewable @State var tmdbManager: TMDBManager?

    if let tmdbManager {
        NavigationStack {
            TVDetailView(
                displayServer: .constant(.moviesAPI),
                result: SearchResult(
                    id: 38867,
                    mediaType: .tv,
                    title: nil,
                    name: "Lab Rats",
                    posterPath: "/lcQMvn9ZptPd3dxn0a17viRfi7Y.jpg",
                    overview: """
            Leo is an ordinary teenager who has moved into a high-tech "smart" house with his mother, inventor stepfather and Eddy, the computer that runs the house. Leo's life becomes less ordinary when, one day, he discovers a secret underground lab that houses three experiments: superhuman teenagers. The trio -- Adam, the strong one, Bree, the fast one and Chase, the smart one -- convinces Leo and his parents to let them leave their lab and join Leo at school, where they try to fit in while having to manage their unpredictable bionic strengths. As Leo figures out a way to keep his new pals' bionic abilities a secret, they help him build self-confidence.
            """
                )
            )
            .environment(tmdbManager)
            .environment(BlockingService())
        }
    } else {
        ProgressView()
            .task {
                tmdbManager = try? .init()
            }
    }
}
