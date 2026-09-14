//
//  ContentView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

struct Root: View {

    @State private var tmdbManager: TMDBManager?

    @State private var error: String?
    @State private var showError: Bool = false

    var body: some View {
        VStack {
            if let tmdbManager {
                NavigationStack {
                    Home()
                }
                .environment(tmdbManager)
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
                let manager = try TMDBManager()
                self.tmdbManager = manager
            } catch {
                self.error = error.localizedDescription
                self.showError = true
            }
        }
    }
}

#Preview {
    Root()
}
