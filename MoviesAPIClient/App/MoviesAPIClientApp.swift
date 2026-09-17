//
//  MoviesAPIClientApp.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import SwiftData
import MoviesAPICore

@main
struct MoviesAPIClientApp: App {
    private let modelContainer: ModelContainer = {
        do {
            let schema = Schema(versionedSchema: MoviesSchemaV2.self)
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Could not create model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Root()
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
#if os(macOS)
        .windowToolbarStyle(
            .expanded
        )
#endif
    }
}
