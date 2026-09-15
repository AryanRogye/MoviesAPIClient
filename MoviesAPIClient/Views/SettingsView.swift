//
//  SettingsView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(BlockingService.self) var blockingService

    var body: some View {
        if blockingService.isNetworkFilteringReady {
            Label("Blocking Ready", systemImage: "checkmark.circle.fill")
        } else {
            ProgressView("Preparing Blocking")
        }
    }
}
