#if os(macOS)
//
//  AppDelegate.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/18/26.
//

import AppKit
import SwiftData

public class AppDelegate: NSObject, NSApplicationDelegate {

    var appCoordinator: AppCoordinator?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        guard !ProcessInfo.isSwiftUIPreview else { return }

        appCoordinator = AppCoordinator()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        appCoordinator?.openApp()
        return true
    }

    public func applicationWillTerminate(_ notification: Notification) {
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

@MainActor
class AppCoordinator {

    let windowCoordinator = WindowCoordinator()

    private let modelContainer: ModelContainer = {
        do {
            let schema = Schema(versionedSchema: MoviesSchemaV2.self)
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Could not create model container: \(error)")
        }
    }()

    init() {
        openApp()
    }

    let appID = UUID().uuidString

    public func openApp() {
        windowCoordinator.showWindow(
            id: appID,
            title: "MoviesAPIClient",
            content: MacOSRoot()
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark),
            size: .init(width: 500, height: 500),
            isMiniaturizable: true,
            alwaysActiveFocusedLook: true
        )
    }
}

#endif
