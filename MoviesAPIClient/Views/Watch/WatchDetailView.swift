//
//  WatchDetailView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import MoviesAPICore

struct WatchDetailView: View {

    let result: KTSearchResult
    var restoredPlayback: PlaybackSession.Playback?
    @AppStorage("DisplayServer") private var displayServerRawValue = KTDisplayServer.moviesApi.rawValue

    private var displayServer: KTDisplayServer {
        KTDisplayServer.entries.first { $0.rawValue == displayServerRawValue } ?? .moviesApi
    }

    private var displayServerBinding: Binding<KTDisplayServer> {
        Binding(
            get: { displayServer },
            set: { displayServerRawValue = $0.rawValue }
        )
    }

    var body: some View {
        switch result.mediaType {
        case .movie:
            MovieDetailView(
                displayServer: displayServerBinding,
                result: result,
                restoredURL: restoredPlayback?.movieURL(for: result)
            )
        case .tv:
            TVDetailView(
                displayServer: displayServerBinding,
                result: result,
                restoredPlayback: restoredPlayback?.tvPlayback(for: result)
            )
        case .person:
            Text("Not Yet Supported")
        default:
            Text("Unkown Media Type")
        }
    }
}
