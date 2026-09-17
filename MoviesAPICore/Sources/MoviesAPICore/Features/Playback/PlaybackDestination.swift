//
//  PlaybackDestination.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/17/26.
//

import SwiftUI

public struct PlaybackDestination: View {

    @Environment(PlaybackSession.self) private var playbackSession

    public init() {}

    public var body: some View {
        if let playback = playbackSession.playback {
            WatchDetailView(result: playback.result, restoredPlayback: playback)
        } else {
            ContentUnavailableView(
                "Nothing Playing",
                systemImage: "play.slash"
            )
        }
    }
}
