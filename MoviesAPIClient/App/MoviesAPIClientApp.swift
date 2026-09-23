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
#if os(iOS)
    private let modelContainer: ModelContainer = {
        do {
            let schema = Schema(versionedSchema: MoviesSchemaV2.self)
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Could not create model container: \(error)")
        }
    }()
#endif

#if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif

    var body: some Scene {
#if os(iOS)
        WindowGroup {
            Root()
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
#elseif os(macOS)
        WindowGroup { EmptyView().destroyViewWindow() }
#endif
    }
}
