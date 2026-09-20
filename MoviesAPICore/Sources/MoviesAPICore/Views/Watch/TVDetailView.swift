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

    @AppStorage("EnableAutoPlay") private var enableAutoPlay: Bool = false
    @State private var timeInfo: TimeInfo? = nil
    @State private var timeInfoTask: Task<Void, Never>?
    @State private var waitingForAutoPlayLoad = false

    @State private var iFrameLogs: [String] = []

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let tvUrl {
#if os(iOS)
                    EmbeddedMovieView(url: tvUrl) { timeInfo in
                        self.timeInfo = timeInfo

                        if waitingForAutoPlayLoad,
                           timeInfo.currentTime < 10,
                           timeInfo.duration > 0 {
                            waitingForAutoPlayLoad = false
                        }
                    } iFrameLogs: { log in
                        addLog(log)
                    }
                    .id(reloadID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .padding(.horizontal, 10)
#elseif os(macOS)
                    EmbeddedMovieView(url: tvUrl) { timeInfo in
                        self.timeInfo = timeInfo

                        if waitingForAutoPlayLoad,
                           timeInfo.currentTime < 10,
                           timeInfo.duration > 0 {
                            waitingForAutoPlayLoad = false
                        }
                    } iFrameLogs: { log in
                        addLog(log)
                    }
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

#if os(macOS)
            ToolbarSpacer(.flexible)
#endif

            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
#if os(macOS)
                    Button {
                        hideSeasonsAndEpisodes.toggle()
                    } label: {
                        Label(
                            "Player Only",
                            systemImage: hideSeasonsAndEpisodes ? "eye.slash" : "eye"
                        )
                        .labelStyle(.titleAndIcon)
                    }
#endif
                    NavigationLink {
                        IFrameLogsView(logs: $iFrameLogs)
                    } label: {
                        Text("Logs")
                    }
                    .buttonStyle(.plain)

                    Toggle("Enable Autoplay", isOn: $enableAutoPlay)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
                .environment(\.menuOrder, .fixed)

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
        .onDisappear {
            timeInfoTask?.cancel()
            timeInfoTask = nil
        }
        /// If we pick a season number, we must clear out any existing values
        .onChange(of: selectedSeasonNumber) { _, newValue in
            if let newValue {
                seasonInfo = nil
                tvUrl = nil
                selectedEpisode = nil
                selectedEpisodeNumber = nil
                loadSeason(season: newValue)
            }
        }
        /// If we pick a episode number, we clear out any web values so the view is clear
        .onChange(of: selectedEpisode) { _, newValue in
            if let newValue, let selectedSeasonNumber {
                tvUrl = nil
                reloadID = UUID()
                loadTVShow(season: selectedSeasonNumber, episode: Int(newValue.episodeNumber))
            }
        }
        /// If we change a server, we must reload
        .onChange(of: displayServer) {
            if let selectedSeasonNumber, let selectedEpisode {
                self.tvUrl = nil
                reloadID = UUID()
                loadTVShow(season: selectedSeasonNumber, episode: Int(selectedEpisode.episodeNumber))
            }
        }
        .onChange(of: enableAutoPlay) { _, newValue in
            if enableAutoPlay {
                beginAutoPlay()
            } else {
                timeInfoTask?.cancel()
                timeInfoTask = nil
            }
        }
        .task {
            if let selectedSeasonNumber, let selectedEpisodeNumber {
                loadSeason(season: selectedSeasonNumber, pickingEpisode: selectedEpisodeNumber)
            }
        }
        .task {
            if enableAutoPlay {
                beginAutoPlay()
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

    func addLog(_ log: String) {
        iFrameLogs.append(log)

        if iFrameLogs.count > 200 {
            iFrameLogs.removeFirst(iFrameLogs.count - 200)
        }
    }

    private func beginAutoPlay() {
        guard timeInfoTask == nil else { return }
        timeInfoTask = Task.detached(priority: .background) {
            while !Task.isCancelled {

                guard !(await waitingForAutoPlayLoad) else {
                    try? await Task.sleep(for: .seconds(1))
                    continue
                }

                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }

                guard let timeInfo = await timeInfo else { continue }
                guard let seasonInfo = await seasonInfo else { continue }
                guard let selectedEpisode = await selectedEpisode else { continue }

                let remaining = timeInfo.duration - timeInfo.currentTime

                guard remaining > 0, remaining < 25 else {
                    continue
                }

                guard let index = seasonInfo.episodes.firstIndex(
                    where: { $0.episodeNumber == selectedEpisode.episodeNumber }
                ) else {
                    continue
                }

                let nextIndex = index + 1

                guard seasonInfo.episodes.indices.contains(nextIndex) else {
                    continue
                }

                Task { @MainActor in
                    self.waitingForAutoPlayLoad = true
                    self.timeInfo = nil
                    self.selectedEpisode = seasonInfo.episodes[nextIndex]
                }
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

private struct IFrameLogsView: View {
    @Binding var logs: [String]

    @Environment(\.dismiss) var dismiss

    var body: some View {
        List {
            if logs.isEmpty {
                Text("No Logs Yet")
            } else {
                ForEach(
                    Array(logs.reversed()).enumerated(),
                    id: \.offset
                ) { index, log in
                    HStack(alignment: .top, spacing: 10) {
                        Text("#\(logs.count - index)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 35, alignment: .trailing)

                        Text(log)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .navigationTitle("IFrame Logs")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                }
            }

#if os(macOS)
            ToolbarSpacer(.flexible)
#endif

            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    logs.removeAll()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(logs.isEmpty)
                .help("Clear Logs")
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
            .environment(PlaybackSession())
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
