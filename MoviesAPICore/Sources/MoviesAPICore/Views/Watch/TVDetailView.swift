//
//  TVDetailView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/17/26.
//

import SwiftUI
import SwiftData
import WebKit

public struct TVDetailView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) var playbackSession
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @Query var history: [History]
    @Binding var displayServer: KTDisplayServer
    let result: KTSearchResult

    public init(
        displayServer: Binding<KTDisplayServer>,
        result: KTSearchResult,
        restoredPlayback: PlaybackSession.TVPlayback? = nil
    ) {
        self._displayServer = displayServer
        self.result = result
        self._selectedSeasonNumber = .init(initialValue: restoredPlayback?.seasonNumber)
        self._seasonInfo = .init(initialValue: restoredPlayback?.seasonInfo)
        self._selectedEpisode = .init(initialValue: restoredPlayback?.episode)
        self._tvUrl = .init(initialValue: restoredPlayback?.url)
    }
    public init(displayServer: Binding<KTDisplayServer>, result: KTSearchResult, seasonNumber: Int, episodeNumber: Int) {
        self._displayServer = displayServer
        self.result = result
        self._selectedSeasonNumber = .init(initialValue: seasonNumber)
        self._selectedEpisodeNumber = .init(initialValue: episodeNumber)
    }

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var tvShow: KTTVShow?
    @State private var selectedSeasonNumber: Int? = nil
    @State private var selectedEpisodeNumber: Int? = nil

    @State private var loadSeasonTask: Task<Void, Never>?
    @State private var isLoadingSeason = false

    @State private var seasonInfo: KTSeasonInfo?
    @State private var selectedEpisode: KTEpisode? = nil

    @State private var tvUrl: URL?
    @State private var reloadID = UUID()

    @State private var hideSeasonsAndEpisodes: Bool = false

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let tvUrl {
#if os(iOS)
                    EmbeddedMovieView(url: tvUrl)
                        .id(reloadID)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .padding(.horizontal, 10)
#elseif os(macOS)
                    EmbeddedMovieView(url: tvUrl)
                        .id(reloadID)
                        .frame(maxWidth: .infinity)
                        .frame(
                            height: hideSeasonsAndEpisodes
                            ? geometry.size.height
                            : 400
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, hideSeasonsAndEpisodes ? 10 : 0)
#endif
                } else {
                    EpisodeImageView(
                        result: result,
                        tvShow: tvShow
                    )
                }

                if !hideSeasonsAndEpisodes {

                    TVShowInfo(
                        selectedEpisode: selectedEpisode
                    )

                    SeasonsView(
                        tvShow: tvShow,
                        isLoadingSeason: isLoadingSeason,
                        selectedSeasonNumber: $selectedSeasonNumber
                    )

                    EpisodesView(
                        seasonInfo: seasonInfo,
                        selectedEpisode: $selectedEpisode
                    )
                    .padding(.bottom, 24)
                }
            }
        }
        .scrollDisabled(hideSeasonsAndEpisodes)
        .navigationBarBackButtonHidden()
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
                loadTVShow(season: selectedSeasonNumber, episode: Int(newValue.episodeNumber))
            }
        }
        .onChange(of: selectedSeasonNumber) { _, newValue in
            if let newValue {
                seasonInfo = nil
                selectedEpisode = nil
                selectedEpisodeNumber = nil
                loadSeason(season: newValue)
            }
        }
        .onChange(of: displayServer) {
            if let selectedSeasonNumber, let selectedEpisode {
                self.tvUrl = nil
                reloadID = UUID()
                loadTVShow(season: selectedSeasonNumber, episode: Int(selectedEpisode.episodeNumber))
            }
        }
        .task {
            if let selectedSeasonNumber, let selectedEpisodeNumber {
                loadSeason(season: selectedSeasonNumber, pickingEpisode: selectedEpisodeNumber)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    if playbackSession.isPlaying(result) {
                        playbackSession.stop()
                    }
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
#if os(macOS)
                Button {
                    withAnimation(.spring) {
                        hideSeasonsAndEpisodes.toggle()
                    }
                } label: {
                    Image(systemName: hideSeasonsAndEpisodes ? "eye.slash" : "eye")
                }
#endif

                Picker("Server", selection: $displayServer) {
                    ForEach(KTDisplayServer.entries, id: \.self) { server in
                        Text(server.rawValue)
                            .tag(server)
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)

                if let tvUrl {
                    Button {
                        playbackSession.webView?.load(tvUrl)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            do {
                tvShow = try await tmdbManager.infoOnTV(for: Int(result.id))
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }

    private func loadTVShow(season: Int, episode: Int) {
        let tmdb_show_id = result.id

        do {
            let tvUrlString = displayServer.loadTvShow(showId: tmdb_show_id, season: Int32(season), episode: Int32(episode))
            guard let url = URL(string: tvUrlString) else {
                throw DisplayServerError.cantConstructURL
            }

            if let history = history.first(where: {
                $0.resultId == Int(result.id) &&
                $0.mediaType == .episode &&
                $0.season == season &&
                $0.episode == episode
            }) {
                history.watchedAt = .now
            } else {
                let history = History(
                    resultId: Int(result.id),
                    name: result.name ?? result.title ?? "",
                    mediaType: .episode,
                    season: season,
                    episode: episode,
                    posterPath: result.posterPath
                )

                modelContext.insert(history)
            }

            self.startPlaybackSession(with: url, season: season)
            self.tvUrl = url
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }

    private func startPlaybackSession(with url: URL, season: Int) {
        guard let seasonInfo, let selectedEpisode else { return }
        playbackSession.startEpisode(
            result: result,
            url: url,
            seasonInfo: seasonInfo,
            episode: selectedEpisode,
            seasonNumber: season
        )
    }

    private func loadSeason(season: Int, pickingEpisode: Int? = nil) {
        if isLoadingSeason { return }
        loadSeasonTask = Task {
            isLoadingSeason = true
            defer { isLoadingSeason = false }
            do {
                seasonInfo = try await tmdbManager.seasonInfo(for: Int(result.id), seasonNumber: season)
                if let pickingEpisode, let seasonInfo {
                    for episode in seasonInfo.episodes {
                        if (episode.episodeNumber == pickingEpisode) {
                            self.selectedEpisode = episode
                            return
                        }
                    }
                }
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}

private struct EpisodeImageView: View {

    let result: KTSearchResult
    let tvShow: KTTVShow?

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
                Text(result.overview ?? "")
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

private struct TVShowInfo: View {
    let selectedEpisode: KTEpisode?

    var body: some View {
        if let selectedEpisode {
            VStack(alignment: .leading, spacing: 8) {
                Text(selectedEpisode.name)
                    .font(.title3)
                    .fontWeight(.semibold)

                ExpandableText(
                    text: selectedEpisode.overview,
                    tintColor: .yellow,
                    font: .preferredFont(forTextStyle: .body),
                    background: .black
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 32)
        }
    }
}

private struct SeasonsView: View {

    let tvShow: KTTVShow?
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
                                selectedSeasonNumber == Int(season.seasonNumber)
                                ? .primary
                                : .secondary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background {
                                Capsule()
                                    .fill(
                                        selectedSeasonNumber == Int(season.seasonNumber)
                                        ? .white.opacity(0.16)
                                        : .white.opacity(0.06)
                                    )
                            }
                            .onTapGesture {
                                guard !isLoadingSeason else { return }
                                selectedSeasonNumber = Int(season.seasonNumber)
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

    let seasonInfo: KTSeasonInfo?
    @Binding var selectedEpisode: KTEpisode?

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

#if DEBUG
#Preview {
    @Previewable @State var tmdbManager: TMDBManager?

    if let tmdbManager {
        NavigationStack {
            TVDetailView(
                displayServer: .constant(.moviesApi),
                result: KTSearchResult(
                    id: 38867,
                    mediaType: .tv,
                    title: nil,
                    name: "Lab Rats",
                    posterPath: "/lcQMvn9ZptPd3dxn0a17viRfi7Y.jpg",
                    overview: """
            Leo is an ordinary teenager who has moved into a high-tech "smart" house with his mother, inventor stepfather and Eddy, the computer that runs the house. Leo's life becomes less ordinary when, one day, he discovers a secret underground lab that houses three experiments: superhuman teenagers. The trio -- Adam, the strong one, Bree, the fast one and Chase, the smart one -- convinces Leo and his parents to let them leave their lab and join Leo at school, where they try to fit in while having to manage their unpredictable bionic strengths. As Leo figures out a way to keep his new pals' bionic abilities a secret, they help him build self-confidence.
            """,
                    releaseDate: nil,
                    firstAirDate: nil
                )
            )
            .environment(tmdbManager)
            .environment(BlockingService())
            .modelContainer(for: [Favorite.self, History.self], inMemory: true)
        }
    } else {
        ProgressView()
            .task {
                do {
                    tmdbManager = try .init(
                        tmdbClient: TMDBClientPreview(),
                        token: "preview"
                    )
                } catch {
                    print(error.localizedDescription)
                }
            }
    }
}
#endif
