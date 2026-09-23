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

#if os(macOS)
    @Environment(WindowCoordinatorContainer.self) var windowContainer
#endif
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

#if os(macOS)
    @State fileprivate var menubarController = TVDetailMenubarController()
#endif

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
    @State private var videoFrameLogs: [String] = []
    @State private var navigationLogs: [String] = []

    @State private var showCreateCollection: Bool = false
    @State private var collectionName: String = ""
    @State private var collectionResultToAdd: KTSearchResult?

    @State private var historyAppliedTo: History?

    @State var webviewModel: EmbeddedMovieViewModel = .init()

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if let tvUrl {
#if os(iOS)
                    EmbeddedMovieView(url: tvUrl, vm: webviewModel) { timeInfo in
                        self.timeInfo = timeInfo

                        if waitingForAutoPlayLoad,
                           timeInfo.currentTime < 10,
                           timeInfo.duration > 0 {
                            waitingForAutoPlayLoad = false
                        }
                    } iFrameLogs: { log in
                        addLog(log)
                    } videoFrameLogs: { log in
                        addVideoLog(log)
                    } navigationLogs: { log in
                        addNavigationLog(log)
                    }
                    .id(reloadID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .padding(.horizontal, 10)
#elseif os(macOS)
                    EmbeddedMovieView(url: tvUrl, vm: webviewModel) { timeInfo in
                        self.timeInfo = timeInfo

                        if waitingForAutoPlayLoad,
                           timeInfo.currentTime < 10,
                           timeInfo.duration > 0 {
                            waitingForAutoPlayLoad = false
                        }
                    } iFrameLogs: { log in
                        addLog(log)
                    } videoFrameLogs: { log in
                        addVideoLog(log)
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
        .navigationTitle(result.name ?? result.title ?? "")
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .onDisappear {
#if os(macOS)
            webviewModel.stopPlayback()
            menubarController.removeMenubarItems()
#endif
            guard let timeInfo else { return }
            updateLastStoppedAt(with: timeInfo)
        }
        .modifier(CreateCollectionViewModifier(
            showCreateCollection: $showCreateCollection,
            collectionName: $collectionName,
            collectionResultToAdd: $collectionResultToAdd
        ))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
#if os(macOS)
                    webviewModel.stopPlayback()
#endif
                    if let timeInfo {
                        updateLastStoppedAt(with: timeInfo)
                    }
                    if playbackSession.isPlaying(result) {
                        playbackSession.stop()
                    }
#if os(macOS)
                    menubarController.removeMenubarItems()
#endif

                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                }
            }

#if os(macOS)
            ToolbarSpacer(.flexible)
#endif

            ToolbarItemGroup(placement: .primaryAction) {
#if DEBUG
                if let timeInfo {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.yellow)
                }
#endif
                Menu {
#if os(macOS)
                    Button("Freeze Proccess") { webviewModel.freezeProcess() }
                    Button("UnFreeze Proccess") { webviewModel.unfreezeProcess() }
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
#if os(iOS)
                    NavigationLink {
                        IFrameLogsView(
                            logs: $iFrameLogs,
                            videoLogs: $videoFrameLogs,
                            navigationLogs: $navigationLogs
                        )
                    } label: {
                        Text("Logs")
                    }
                    .buttonStyle(.plain)
#endif

                    Toggle("Enable Autoplay", isOn: $enableAutoPlay)

                    CollectionFavoriteMenu(
                        result: result,
                        showCreateCollection: $showCreateCollection,
                        collectionName: $collectionName,
                        collectionResultToAdd: $collectionResultToAdd
                    )

                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
                .environment(\.menuOrder, .fixed)

                Menu {
                    ForEach(KTDisplayServer.entries, id: \.self) { server in
                        Button {
                            self.displayServer = server
                            self.timeInfo = nil
                        } label: {
                            if displayServer == server {
                                Label(server.rawValue, systemImage: "checkmark")
                            } else {
                                Text(server.rawValue)
                            }
                        }
                    }
                } label: {
                    Text(displayServer.rawValue)
                        .foregroundStyle(.yellow)
                }
                .tint(.yellow)

                if let tvUrl {
                    Button {
#if os(macOS)
                        reloadID = UUID()
#else
                        playbackSession.webView?.load(tvUrl)
#endif
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
#if os(macOS)
            menubarController.assignLogs(
                iFrame: $iFrameLogs,
                videoFrame: $videoFrameLogs,
                navigation: $navigationLogs
            )
            menubarController.assignWindowContainer(windowContainer)
            menubarController.attachMenubarItems()
#endif
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

    func addNavigationLog(_ log: String) {
        navigationLogs.append(log)

        if navigationLogs.count > 200 {
            navigationLogs.removeFirst(navigationLogs.count - 200)
        }
    }

    func addVideoLog(_ log: String) {
        videoFrameLogs.append(log)

        if videoFrameLogs.count > 200 {
            videoFrameLogs.removeFirst(videoFrameLogs.count - 200)
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

    private func updateLastStoppedAt(with timeInfo: TimeInfo) {
        guard let historyAppliedTo else { return }
        historyAppliedTo.lastStoppedAt = timeInfo.currentTime
        try? modelContext.save()
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
                self.historyAppliedTo = history
            } else {
                let history = History(
                    resultId: Int(result.id),
                    name: result.name ?? result.title ?? "",
                    mediaType: .episode,
                    season: season,
                    episode: episode,
                    posterPath: result.posterPath
                )
                self.historyAppliedTo = history

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
                    background: .black,
                    foregroundStyle: .secondary
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

    @Namespace private var nm

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
                        let seasonNumber = Int(season.seasonNumber)
                        let isSelected = selectedSeasonNumber == seasonNumber

                        Text("Season \(season.seasonNumber)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(
                                isSelected ? .primary : .secondary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(.yellow.opacity(0.16))
                                        .background {
                                            Capsule()
                                                .stroke(
                                                    .yellow.opacity(0.6),
                                                    style: .init(lineWidth: 1)
                                                )
                                        }
                                        .shadow(
                                            color: .yellow,
                                            radius: 8
                                        )
                                        .matchedGeometryEffect(
                                            id: "ACTIVE_SEASON_PILL",
                                            in: nm
                                        )
                                } else {
                                    Capsule()
                                        .fill(.white.opacity(0.06))
                                }
                            }
                            .onTapGesture {
                                guard !isLoadingSeason else { return }

                                withAnimation(
                                    .spring(
                                        response: 0.3,
                                        dampingFraction: 0.7
                                    )
                                ) {
                                    selectedSeasonNumber = seasonNumber
                                }
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

    @Namespace private var nm

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
                    ForEach(seasonInfo.episodes, id: \.id) { episode in
                        let isSelected = selectedEpisode == episode

                        Text("Episode \(episode.episodeNumber)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(
                                isSelected ? .primary : .secondary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background {
                                if isSelected {
                                    Capsule()
                                        .fill(.yellow.opacity(0.16))
                                        .background {
                                            Capsule()
                                                .stroke(
                                                    .yellow.opacity(0.6),
                                                    style: .init(lineWidth: 1)
                                                )
                                        }
                                        .shadow(
                                            color: .yellow,
                                            radius: 8
                                        )
                                        .matchedGeometryEffect(
                                            id: "ACTIVE_EPISODE_PILL",
                                            in: nm
                                        )
                                } else {
                                    Capsule()
                                        .fill(.white.opacity(0.06))
                                }
                            }
                            .onTapGesture {
                                withAnimation(
                                    .spring(
                                        response: 0.3,
                                        dampingFraction: 0.7
                                    )
                                ) {
                                    selectedEpisode = episode
                                }
                            }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
        }
    }
}


#if os(macOS)
@MainActor
private final class TVDetailMenubarController: NSObject {

    private var windowContainer: WindowCoordinatorContainer?

    private var onIFrameLogs: Binding<[String]>?
    private var onVideoFrameLogs: Binding<[String]>?
    private var onNavigationLogs: Binding<[String]>?

    private var debugMenuItem: NSMenuItem?

    private let windowID = UUID().uuidString

    override init() {
        super.init()
    }

    public func assignLogs(
        iFrame: Binding<[String]>,
        videoFrame: Binding<[String]>,
        navigation: Binding<[String]>
    ) {
        onIFrameLogs = iFrame
        onVideoFrameLogs = videoFrame
        onNavigationLogs = navigation
    }

    public func assignWindowContainer(_ windowContainer: WindowCoordinatorContainer) {
        self.windowContainer = windowContainer
    }

    @objc private func showLogs() {

        guard let onIFrameLogs else { return }
        guard let onVideoFrameLogs else { return }
        guard let onNavigationLogs else { return }

        windowContainer?.windowCoordinator.showWindow(
            id: windowID,
            title: "Logs",
            content: NavigationStack {
                IFrameLogsView(
                    logs: onIFrameLogs,
                    videoLogs: onVideoFrameLogs,
                    navigationLogs: onNavigationLogs
                )
            }
        )
    }

    public func attachMenubarItems() {
        guard debugMenuItem == nil else { return }

        let menuItem = NSMenuItem(
            title: "Debug",
            action: nil,
            keyEquivalent: ""
        )

        let menu = NSMenu(title: "Debug")

        let logs = NSMenuItem(
            title: "Logs",
            action: #selector(showLogs),
            keyEquivalent: ""
        )

        logs.target = self

        menu.addItem(logs)
        menuItem.submenu = menu

        NSApp.mainMenu?.addItem(menuItem)

        debugMenuItem = menuItem
    }

    public func removeMenubarItems() {
        guard let debugMenuItem else {
            print("NO DEBUG MENU ITEM")
            return
        }

        guard let mainMenu = NSApp.mainMenu else {
            print("NO MAIN MENU")
            return
        }

        print("BEFORE:", mainMenu.items.map(\.title))

        if let index = mainMenu.items.firstIndex(where: { $0 === debugMenuItem }) {
            print("FOUND AT INDEX:", index)

            mainMenu.removeItem(at: index)

            print("AFTER:", mainMenu.items.map(\.title))
        } else {
            print("STORED ITEM IS NOT IN MAIN MENU")
        }

        self.debugMenuItem = nil
    }
}
#endif

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
