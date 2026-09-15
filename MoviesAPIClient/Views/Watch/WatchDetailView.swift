//
//  WatchDetailView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import SharedLogic

struct WatchDetailView: View {

    let result: KTSearchResult
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
            MovieDetailView(displayServer: displayServerBinding, result: result)
        case .tv:
            TVDetailView(displayServer: displayServerBinding, result: result)
        case .person:
            Text("Not Yet Supported")
        default:
            Text("Unkown Media Type")
        }
    }
}
