//
//  Home.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI

struct Home: View {

    var body: some View {
        ContentUnavailableView(
            "Home",
            systemImage: "house",
            description: Text("Use the Search tab to find movies, TV shows, and people.")
        )
        .navigationTitle("Home")
    }
}
