//
//  PlaybackSession.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/17/26.
//

import Foundation
import WebKit

@Observable
@MainActor
public final class PlaybackSession {
    public struct TVPlayback {
        public let url: URL
        public let seasonInfo: KTSeasonInfo
        public let episode: KTEpisode
        public let seasonNumber: Int
    }

    public struct Playback {
        public let result: KTSearchResult
        public let url: URL
        public let episode: TVPlayback?

        public var title: String? {
            result.title ?? result.name
        }

        public var posterPath: String? {
            result.posterPath
        }

        public func movieURL(for result: KTSearchResult) -> URL? {
            guard self.result.id == result.id, episode == nil else { return nil }
            return url
        }

        public func tvPlayback(for result: KTSearchResult) -> TVPlayback? {
            guard self.result.id == result.id else { return nil }
            return episode
        }
    }

    public init() {}

    public var webView: WKWebView?
    public var sourceTab: TabID?
    public private(set) var playback: Playback?
    public private(set) var activationID = UUID()

    public var isActive: Bool {
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
