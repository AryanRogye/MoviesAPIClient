//
//  MovieDetailView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import SwiftData
import WebKit

public struct MovieDetailView: View {

    @Environment(\.modelContext) var modelContext
    @Environment(PlaybackSession.self) var playbackSession
    @Environment(\.dismiss) var dismiss

    @Query var history: [History]
    @Binding var displayServer: KTDisplayServer
    let result: KTSearchResult

    public init(
        displayServer: Binding<KTDisplayServer>,
        result: KTSearchResult,
        restoredURL: URL? = nil
    ) {
        self._displayServer = displayServer
        self.result = result
        self._movieUrl = State(initialValue: restoredURL)
        self._hasLoadedMovie = State(initialValue: restoredURL != nil)
    }

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var movieUrl: URL?
    @State private var hasLoadedMovie: Bool = false
    @State private var reloadID = UUID()

    @State private var showCreateCollection: Bool = false
    @State private var collectionName: String = ""
    @State private var collectionResultToAdd: KTSearchResult?

    @State var webviewModel: EmbeddedMovieViewModel = .init()

    private var titleLineLimit: Int {
        if let title = result.title {
            title.count <= 25 ? 1 : 2
        } else {
            1
        }
    }

#if os(iOS)
    var overviewFont: UIFont {
        let descriptor = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: .subheadline)
            .withDesign(.serif)!
            .addingAttributes([
                .traits: [
                    UIFontDescriptor.TraitKey.weight: UIFont.Weight.medium
                ]
            ])

        return UIFont(descriptor: descriptor, size: 0)
    }
#elseif os(macOS)
    var overviewFont: NSFont {
        let size = NSFont.preferredFont(forTextStyle: .subheadline).pointSize

        let descriptor = NSFontDescriptor
            .preferredFontDescriptor(forTextStyle: .subheadline)
            .withDesign(.serif)!
            .addingAttributes([
                .traits: [
                    NSFontDescriptor.TraitKey.weight: NSFont.Weight.medium
                ]
            ])

        return NSFont(descriptor: descriptor, size: size)!
    }
#endif

    public var body: some View {
        ZStack {
            if let movieUrl {
#if os(iOS)
                GeometryReader { proxy in
                    EmbeddedMovieView(url: movieUrl, vm: webviewModel)
                        .id(reloadID)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .padding(.horizontal, 10)
                }
                .frame(height: 200)
#elseif os(macOS)
                EmbeddedMovieView(url: movieUrl, vm: webviewModel)
                    .id(reloadID)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
#endif
            } else {
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        MovieImageBackground(imagePath: result.posterPath)
                            .ignoresSafeArea()
                    }
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(result.title ?? "")
                                .font(.system(.largeTitle, design: .serif))
                                .fontWeight(.semibold)
                                .lineLimit(titleLineLimit)
                                .minimumScaleFactor(0.8)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)


                            ExpandableText(
                                text: result.overview ?? "",
                                tintColor: .yellow,
                                font: overviewFont,
                                background: .black,
                                foregroundStyle: .white.opacity(0.65)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                            Button {
                                loadMovie()
                            } label: {
                                Label("Play Movie", systemImage: "play.fill")
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 20)
                                    .glassEffect(.clear.tint(.yellow.opacity(0.1).mix(with: .black, by: 0.8)), in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                    }
            }
        }
        .navigationBarBackButtonHidden()
        .navigationTitle(result.name ?? result.title ?? "")
        .frame(maxWidth: .infinity)
        .onChange(of: displayServer) {
            if hasLoadedMovie {
                movieUrl = nil
                reloadID = UUID()
                loadMovie()
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
#if os(macOS)
                    webviewModel.stopPlayback()
#endif
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
                    Button("Freeze Proccess") { webviewModel.freezeProcess() }
                    Button("UnFreeze Proccess") { webviewModel.unfreezeProcess() }
#endif
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
                            displayServer = server
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

                if let movieUrl {
                    Button {
#if os(macOS)
                        reloadID = UUID()
#else
                        playbackSession.webView?.load(movieUrl)
#endif
                    } label: {
                        Image(systemName: "arrow.clockwise")
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
        .modifier(CreateCollectionViewModifier(
            showCreateCollection: $showCreateCollection,
            collectionName: $collectionName,
            collectionResultToAdd: $collectionResultToAdd
        ))
#if os(macOS)
        .onDisappear {
            webviewModel.stopPlayback()
        }
#endif
    }

    private func loadMovie() {
        do {
            let movieUrlString = displayServer.loadMovie(movieId: result.id)
            guard let url = URL(string: movieUrlString) else {
                throw DisplayServerError.cantConstructURL
            }

            if let history = history.first(where: {
                $0.resultId == Int(result.id) &&
                $0.mediaType == .movie
            }) {
                history.watchedAt = .now
            } else {
                let history = History(
                    resultId: Int(result.id),
                    name: result.title ?? result.name ?? "",
                    mediaType: .movie,
                    posterPath: result.posterPath
                )

                modelContext.insert(history)
            }

            playbackSession.startMovie(result: result, url: url)

            movieUrl = url
            hasLoadedMovie = true
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }
}

private struct MovieImageBackground: View {

    let imagePath: String?

    var body: some View {
        ZStack(alignment: .center) {
            imageView
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            imageView
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .blur(radius: 15)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.5),
                            .init(color: .black.opacity(0.5), location: 0.6),
                            .init(color: .black, location: 0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.5),
                    .init(color: .black.opacity(0.65), location: 0.72),
                    .init(color: .black.opacity(0.75), location: 0.86),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var imageView: some View {
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
                .clipped()
            }
        }
    }
}

#Preview {
    @Previewable @State var tmdbManager: TMDBManager?

    if let tmdbManager {
        NavigationStack {
            MovieDetailView(
                displayServer: .constant(.moviesApi),
                result: KTSearchResult(
                    id: 969681,
                    mediaType: .movie,
                    title: "Spider-Man: Brand New Day",
                    name: nil,
                    posterPath: "/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg",
                    overview: """
                Fighting crime full-time as Spider-Man in a world that doesn't remember him—and the pressure of seeing his old friends move on without him—sparks a change in Peter Parker he may not have the power to control. But that transformation might also be the only thing that can stop a shocking new threat to the city and those he loves - a powerful villain no one can even see.
                """,
                    releaseDate: nil,
                    firstAirDate: nil
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
