#if os(macOS)
//
//  MacOSRoot.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/18/26.
//

import SwiftUI

struct MacOSRoot: View {

    @Bindable var windowContainer: WindowCoordinatorContainer
    @State private var tmdbManager: TMDBManager?
    @State private var blockingService = BlockingService()
    @State private var playbackSession = PlaybackSession()

    @State private var selectedTab: MacOSTab = .home

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var path = NavigationPath()

    var body: some View {
        ZStack {
            if let tmdbManager {
                VisualEffectView()

                HStack(spacing: 0) {
                    MacOSRootSidebar(selectedTab: $selectedTab, path: $path)
                        .environment(tmdbManager)
                        .environment(blockingService)
                        .environment(playbackSession)

                    Divider()

                    NavigationStack(path: $path) {
                        Group {
                            switch selectedTab {
                            case .home:
                                ComfyHeaderView(tab: .home) {
                                    Home()
                                }

                            case .library:
                                ComfyHeaderView(tab: .library) {
                                    Library()
                                }

                            case .history:
                                ComfyHeaderView(tab: .history) {
                                    HistoryView()
                                }

                            case .settings:
                                ComfyHeaderView(tab: .settings) {
                                    SettingsView()
                                }
                            }
                        }
                        .navigationDestination(for: MacOSRoute.self) { route in
                            switch route {
                            case .searchResults:
                                ScrollView {
                                    SearchResultsView(
                                        searchResults: tmdbManager.searchResults
                                    )
                                }
                            }
                        }
                    }
                    .environment(windowContainer)
                    .environment(tmdbManager)
                    .environment(blockingService)
                    .environment(playbackSession)
                }
            } else {
                ProgressView()
                    .task {
                        do {
                            let manager = try TMDBManager()
                            self.tmdbManager = manager
                        } catch {
                            self.error = error.localizedDescription
                            self.showError = true
                        }
                    }
            }
        }
        .background(.clear)
        .ignoresSafeArea(edges: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ComfyHeaderView<Content: View>: View {

    let tab: MacOSTab
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack {
            ComfyRowView(tab: tab, font: .system(size: 14, weight: .medium, design: .rounded))
                .padding([.top, .horizontal])
                .padding(.bottom, 4)
            Divider()
            content()
        }
    }
}

struct ComfyRowView: View {

    let tab: MacOSTab
    var font: Font = .system(size: 14, weight: .regular, design: .rounded)

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(tab.color)
                .frame(width: 25, height: 25)
                .overlay {
                    ZStack {
                        tab.icon
                            .foregroundStyle(.black)
                            .fontWeight(.black)
                            .scaleEffect(1.04)

                        tab.icon
                            .foregroundStyle(.white)
                            .fontWeight(.black)
                            .scaleEffect(tab.primaryScale)
                    }
                }

            Text(tab.rawValue)
                .font(font)

            Spacer()
        }
    }
}

#endif
