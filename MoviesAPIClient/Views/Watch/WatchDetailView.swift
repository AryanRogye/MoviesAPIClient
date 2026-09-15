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
    @State private var displayServer: KTDisplayServer = .moviesApi

    var body: some View {
        switch result.mediaType {
        case .movie:
            MovieDetailView(displayServer: $displayServer, result: result)
        case .tv:
            TVDetailView(displayServer: $displayServer, result: result)
        case .person:
            Text("Not Yet Supported")
        default:
            Text("Unkown Media Type")
        }
    }
}
