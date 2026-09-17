//
//  SettingsView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import MoviesAPICore

struct SettingsView: View {

    @Environment(TMDBManager.self) var tmdbManager
    @Environment(BlockingService.self) var blockingService

    var body: some View {

        @Bindable var tmdbManager = tmdbManager

        Form {
            Section {
                Toggle("Include Adult Content", isOn: $tmdbManager.includeAdult)
                    .toggleStyle(.switch)
            } header: {
                Label("Search Settings", systemImage: "magnifyingglass")
            }

            Section {
                if blockingService.isNetworkFilteringReady {
                    Label("Blocking Ready", systemImage: "checkmark.circle.fill")
                } else {
                    ProgressView("Preparing Blocking")
                }
            } header: {
                Label("Network", systemImage: "network")
            }
        }
    }
}
