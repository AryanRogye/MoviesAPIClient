//
//  MovieDetailView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

struct MovieDetailView: View {

    @Binding var displayServer: DisplayServer
    let result: SearchResult

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var movieUrl: URL?
    @State private var hasLoadedMovie: Bool = false
    @State private var reloadID = UUID()


    var body: some View {
        VStack {
            if let movieUrl {
#if os(iOS)
                GeometryReader { proxy in
                    EmbeddedMovieView(url: movieUrl)
                        .id(reloadID)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .padding(.horizontal, 10)
                }
                .frame(height: 200)
#elseif os(macOS)
                EmbeddedMovieView(url: movieUrl)
                    .id(reloadID)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                    .padding(.horizontal, 10)
#endif
            } else {
                GeometryReader { geometry in
                    ZStack {
                        MovieImageView(result: result)
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .clipped()
                            .ignoresSafeArea(edges: .top)

                        // Same poster, but blurred only toward the bottom
                        MovieImageView(result: result)
                            .frame(
                                width: geometry.size.width,
                                height: geometry.size.height
                            )
                            .clipped()
                            .ignoresSafeArea(edges: .top)
                            .blur(radius: 12)
                            .mask {
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.55),
                                        .init(color: .black.opacity(0.3), location: 0.68),
                                        .init(color: .black, location: 0.82)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }

                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.45),
                                .init(color: .black.opacity(0.15), location: 0.58),
                                .init(color: .black.opacity(0.55), location: 0.72),
                                .init(color: .black.opacity(0.85), location: 0.86),
                                .init(color: .black, location: 1.0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Text(result.title ?? "")
                                .font(.system(.largeTitle, design: .serif))
                                .fontWeight(.semibold)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)

                            Text(result.overview ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                                .lineSpacing(3)
                                .lineLimit(3)

                            Button {
                                loadMovie()
                            } label: {
                                Label("Play Movie", systemImage: "play.fill")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 64)
                                    .background {
                                        Capsule()
                                            .glassEffect(.clear, in: .capsule)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .bottomLeading
                        )
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: displayServer) {
            if hasLoadedMovie {
                movieUrl = nil
                reloadID = UUID()
                loadMovie()
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

                if movieUrl != nil {
                    Button {
                        reloadID = UUID()
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
    }

    private func loadMovie() {
        do {
            movieUrl = try displayServer.loadMovie(movieId: result.id)
            hasLoadedMovie = true
        } catch {
            self.error = error.localizedDescription
            self.showError = true
        }
    }
}

private struct MovieImageView: View {

    let result: SearchResult

    var imagePath: String? {
        result.posterPath
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
                displayServer: .constant(.moviesAPI),
                result: SearchResult(
                    id: 969681,
                    mediaType: .movie,
                    title: "Spider-Man: Brand New Day",
                    name: nil,
                    posterPath: "/bjiS5ipwxb9JFy3XRRN4OAilSeX.jpg",
                    overview: """
                Fighting crime full-time as Spider-Man in a world that doesn't remember him—and the pressure of seeing his old friends move on without him—sparks a change in Peter Parker he may not have the power to control. But that transformation might also be the only thing that can stop a shocking new threat to the city and those he loves - a powerful villain no one can even see.
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
