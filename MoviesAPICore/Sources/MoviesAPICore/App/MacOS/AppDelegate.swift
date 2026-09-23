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

@Observable
@MainActor
final class WindowCoordinatorContainer {
    let windowCoordinator = WindowCoordinator()
}

@MainActor
class AppCoordinator {

    let windowContainer = WindowCoordinatorContainer()


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

        let targetScreen = AppCoordinator.screenUnderMouse() ?? NSScreen.main

        let size: NSSize
        if let targetScreen {
            size = .init(width: targetScreen.visibleFrame.width - 100, height: targetScreen.visibleFrame.height - 100)
        } else {
            size = .init(width: 500, height: 500)
        }

        let window = windowContainer.windowCoordinator.showWindow(
            id: appID,
            title: "MoviesAPIClient",
            content: MacOSRoot(windowContainer: windowContainer)
                .modelContainer(modelContainer)
                .preferredColorScheme(.dark),
            size: size,
            isMiniaturizable: true,
            alwaysActiveFocusedLook: true
        )

        if let targetScreen {
            let frame = targetScreen.visibleFrame
            window.setFrameOrigin(CGPoint(
                x: frame.midX - window.frame.width / 2,
                y: frame.midY - window.frame.height / 2
            ))
        }

    }

    /**
     * Grab the screen under the mouse
     */
    public nonisolated static func screenUnderMouse() -> NSScreen? {
        let loc = NSEvent.mouseLocation
        return NSScreen.screens.first {
            NSMouseInRect(loc, $0.frame, false)
        }
    }
}

#endif
