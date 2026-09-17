//
//  MoviesAPIClientApp.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import SwiftData

@main
struct MoviesAPIClientApp: App {
    var body: some Scene {
        WindowGroup {
            Root()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [Favorite.self, Collection.self, History.self])
#if os(macOS)
        .windowToolbarStyle(
            .expanded
        )
#endif
    }
}
