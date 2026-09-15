//
//  WatchDetailView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

struct WatchDetailView: View {

    let result: SearchResult


    var body: some View {
        switch result.mediaType {
        case .movie:
            MovieDetailView(result: result)
        case .tv:
            TVDetailView(result: result)
        case .person:
            Text("Not Yet Supported")
        }
    }
}
