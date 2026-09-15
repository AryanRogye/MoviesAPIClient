//
//  SearchResultsRow.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/15/26.
//

import SwiftUI

struct SearchResultsRow: View {
    let result: SearchResult

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            imageView

            description

            Spacer()
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var imageView: some View {
        if let posterPath = result.posterPath,
           let url = URL(
            string: "https://image.tmdb.org/t/p/w500\(posterPath)"
           ) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 90, height: 135)
            .clipShape(.rect(cornerRadius: 8))
        } else {
            ZStack {
                Rectangle()
                    .fill(.quaternary)

                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 90, height: 135)
            .clipShape(.rect(cornerRadius: 8))
        }
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(result.name ?? result.title ?? "Unknown")
                .font(.headline)

            Text(result.mediaType == .tv ? "TV Show" : "Movie")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(result.overview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
    }
}
