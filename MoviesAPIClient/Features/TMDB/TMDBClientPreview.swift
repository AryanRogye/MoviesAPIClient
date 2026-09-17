//
//  TMDBClientPreview.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

#if DEBUG
import SharedLogic

final class TMDBClientPreview: TMDBClientProviding {
    func infoOnTV(id: Int32, token: String) async throws -> KTTVShow {
        KTTVShow(
            id: id,
            name: "Lab Rats",
            overview: "Leo discovers three superhuman teenagers living in a secret underground lab beneath his new home.",
            backdropPath: "/lcQMvn9ZptPd3dxn0a17viRfi7Y.jpg",
            numberOfEpisodes: 98,
            numberOfSeasons: 4,
            seasons: Self.seasons
        )
    }

    func seasonInfo(id: Int32, seasonNumber: Int32, token: String) async throws -> KTSeasonInfo {
        let episodes = (1...6).map { episodeNumber in
            KTEpisode(
                id: seasonNumber * 1_000 + Int32(episodeNumber),
                name: "Episode \(episodeNumber)",
                overview: "Preview episode \(episodeNumber) for season \(seasonNumber).",
                episodeNumber: Int32(episodeNumber),
                seasonNumber: seasonNumber,
                airDate: "2012-02-27",
                runtime: KotlinInt(int: 24),
                stillPath: nil
            )
        }

        return KTSeasonInfo(
            id: id * 10 + seasonNumber,
            airDate: "2012-02-27",
            name: "Season \(seasonNumber)",
            overview: "Mock season data used by SwiftUI previews.",
            posterPath: "/lcQMvn9ZptPd3dxn0a17viRfi7Y.jpg",
            seasonNumber: seasonNumber,
            episodes: episodes
        )
    }

    func nowPlayingMovies(token: String, page: Int32) async throws -> KTNowPlayingMovieResponse {
        KTNowPlayingMovieResponse(
            dates: KTMovieDateRange(maximum: "2026-09-16", minimum: "2026-08-01"),
            page: page,
            results: Self.movies,
            totalPages: 1,
            totalResults: Int32(Self.movies.count)
        )
    }

    func popularMovies(token: String, page: Int32) async throws -> KTMovieListResponse {
        movieResponse(page: page)
    }

    func topRatedMovies(token: String, page: Int32) async throws -> KTMovieListResponse {
        movieResponse(page: page)
    }

    func popularTV(token: String, page: Int32) async throws -> KTTVListResponse {
        tvResponse(page: page)
    }

    func topRatedTV(token: String, page: Int32) async throws -> KTTVListResponse {
        tvResponse(page: page)
    }

    func search(query: String, token: String, includeAdult: Bool) async throws -> KTSearchResponse {
        KTSearchResponse(results: [
            KTSearchResult(
                id: 38867,
                mediaType: .tv,
                title: nil,
                name: "Lab Rats",
                posterPath: "/lcQMvn9ZptPd3dxn0a17viRfi7Y.jpg",
                overview: "A mock search result for SwiftUI previews.",
                releaseDate: nil,
                firstAirDate: "2012-02-27"
            )
        ])
    }

    func trending(token: String) async throws -> KTTrendingResponse {
        let result = KTTrendingResult(
            adult: false,
            backdropPath: "/lcQMvn9ZptPd3dxn0a17viRfi7Y.jpg",
            id: 38867,
            title: nil,
            originalTitle: nil,
            releaseDate: nil,
            video: nil,
            name: "Lab Rats",
            originalName: "Lab Rats",
            firstAirDate: "2012-02-27",
            originCountry: ["US"],
            originalLanguage: "en",
            overview: "A mock trending result for SwiftUI previews.",
            posterPath: "/lcQMvn9ZptPd3dxn0a17viRfi7Y.jpg",
            mediaType: .tv,
            genreIds: [],
            popularity: 100,
            voteAverage: 8.0,
            voteCount: 500
        )

        return KTTrendingResponse(page: 1, results: [result], totalPages: 1, totalResults: 1)
    }

    private func movieResponse(page: Int32) -> KTMovieListResponse {
        KTMovieListResponse(page: page, results: Self.movies, totalPages: 1, totalResults: Int32(Self.movies.count))
    }

    private func tvResponse(page: Int32) -> KTTVListResponse {
        KTTVListResponse(page: page, results: Self.tvShows, totalPages: 1, totalResults: Int32(Self.tvShows.count))
    }

    private static let seasons: [KTSeason] = (1...4).map { seasonNumber in
        KTSeason(
            id: Int32(10_000 + seasonNumber),
            name: "Season \(seasonNumber)",
            seasonNumber: Int32(seasonNumber),
            episodeCount: 6,
            posterPath: "/lcQMvn9ZptPd3dxn0a17viRfi7Y.jpg"
        )
    }

    private static let movies = [
        KTMovieListResult(
            adult: false, backdropPath: nil, genreIds: [], id: 969681,
            originalLanguage: "en", originalTitle: "Preview Movie",
            overview: "A mock movie used by SwiftUI previews.", popularity: 100,
            posterPath: nil, releaseDate: "2026-07-31", title: "Preview Movie",
            video: false, voteAverage: 8.2, voteCount: 250
        )
    ]

    private static let tvShows = [
        KTTVListResult(
            backdropPath: "/lcQMvn9ZptPd3dxn0a17viRfi7Y.jpg", firstAirDate: "2012-02-27",
            genreIds: [], id: 38867, name: "Lab Rats", originCountry: ["US"],
            originalLanguage: "en", originalName: "Lab Rats",
            overview: "A mock TV result used by SwiftUI previews.", popularity: 100,
            posterPath: "/lcQMvn9ZptPd3dxn0a17viRfi7Y.jpg", voteAverage: 8.0, voteCount: 500
        )
    ]
}
#endif
