//
//  MovieDetailView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

struct MovieDetailView: View {

    let result: SearchResult

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var movieUrl: URL?
    @State private var reloadID = UUID()

    var body: some View {
        ScrollView {
            if let movieUrl {
#if os(iOS)
                EmbeddedMovieView(url: movieUrl)
                    .id(reloadID)
                    .frame(width: UIScreen.main.bounds.width - 20, height: 200)
#elseif os(macOS)
                EmbeddedMovieView(url: movieUrl)
                    .id(reloadID)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .padding(.horizontal, 10)
#endif
            }
        }
        .toolbar {
            if movieUrl != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        reloadID = UUID()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .task {
            do {
                movieUrl = try MoviesAPILoader.loadMovie(movieId: result.id)
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}
