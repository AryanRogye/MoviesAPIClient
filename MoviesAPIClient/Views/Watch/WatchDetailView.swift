//
//  WatchDetailView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

struct WatchDetailView: View {

    let result: SearchResult
    @AppStorage("DisplayServer") private var displayServer: DisplayServer = .moviesAPI

    var body: some View {
        switch result.mediaType {
        case .movie:
            MovieDetailView(displayServer: $displayServer, result: result)
        case .tv:
            TVDetailView(displayServer: $displayServer, result: result)
        case .person:
            Text("Not Yet Supported")
        }
    }
}
