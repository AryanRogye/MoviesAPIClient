//
//  PlaybackSession.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/17/26.
//

import Foundation
import SharedLogic
import WebKit

@Observable
@MainActor
final class PlaybackSession {
    struct TVPlayback {
        let url: URL
        let seasonInfo: KTSeasonInfo
        let episode: KTEpisode
        let seasonNumber: Int
    }

    struct Playback {
        let result: KTSearchResult
        let url: URL
        let episode: TVPlayback?

        var title: String? {
            result.title ?? result.name
        }

        var posterPath: String? {
            result.posterPath
        }

        func movieURL(for result: KTSearchResult) -> URL? {
            guard self.result.id == result.id, episode == nil else { return nil }
            return url
        }

        func tvPlayback(for result: KTSearchResult) -> TVPlayback? {
            guard self.result.id == result.id else { return nil }
            return episode
        }
    }

    var webView: WKWebView?
    var sourceTab: TabID?
    private(set) var playback: Playback?
    private(set) var activationID = UUID()

    var isActive: Bool {
        playback != nil
    }

    /// Starts Movie Playback session
    public func startMovie(result: KTSearchResult, url: URL) {
        start(.init(result: result, url: url, episode: nil))
    }

    /// Starts Episode Playback Session
    public func startEpisode(
        result: KTSearchResult,
        url: URL,
        seasonInfo: KTSeasonInfo,
        episode: KTEpisode,
        seasonNumber: Int
    ) {
        start(
            .init(
                result: result,
                url: url,
                episode: .init(
                    url: url,
                    seasonInfo: seasonInfo,
                    episode: episode,
                    seasonNumber: seasonNumber
                )
            )
        )
    }

    /// Inidcator if we're currently playing the result
    public func isPlaying(_ result: KTSearchResult) -> Bool {
        playback?.result.id == result.id
    }

    public func stop() {
        self.webView?.stopLoading()
        self.webView?.navigationDelegate = nil
        self.webView?.uiDelegate = nil
        self.webView = nil

        self.sourceTab = nil
        self.playback = nil
    }

    /// private Wrapper to start
    /// clears the webview if we have to
    /// sets playback
    ///
    /// IMPORTANT: before we set any url for the webview we must call this
    /// this way it'll clear out any stale webviews
    private func start(_ playback: Playback) {
        if self.playback?.url != playback.url {
            webView = nil
        }
        self.playback = playback
        activationID = UUID()
    }
}
