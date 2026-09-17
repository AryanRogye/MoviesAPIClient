//
//  PlaybackDestination.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/17/26.
//

import SwiftUI

struct PlaybackDestination: View {

    @Environment(PlaybackSession.self) private var playbackSession

    var body: some View {
        if let result = playbackSession.result {
            WatchDetailView(result: result, restoresPlayback: true)
        } else {
            ContentUnavailableView(
                "Nothing Playing",
                systemImage: "play.slash"
            )
        }
    }
}
