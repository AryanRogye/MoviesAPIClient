//
//  HomeRow.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/16/26.
//

import SwiftUI

struct HomeRow: View {

    let imagePath: String?
    let name: String
    let mediaType: KTMediaType

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeImageView(imagePath: imagePath)
                .frame(width: 110, height: 165)
                .clipShape(.rect(cornerRadius: 10))

            Text(name)
                .font(.subheadline.weight(.medium))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)
        }
        .frame(width: 110)
        .overlay(alignment: .topTrailing) {
            Text(mediaType.rawValue)
                .font(.caption2.bold())
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .glassEffect(.regular.tint(.yellow.opacity(0.1)), in: .capsule)
                .overlay {
                    Capsule()
                        .strokeBorder(.yellow.opacity(0.2), lineWidth: 1)
                }
                .padding(5)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
    }
}

private struct HomeImageView: View {

    let imagePath: String?

    var body: some View {
        Group {
            if let posterPath = imagePath,
               let url = URL(
                string: "https://image.tmdb.org/t/p/w500\(posterPath)"
               ) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                        .aspectRatio(2/3, contentMode: .fit)
                        .overlay(ProgressView())
                }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipped()
            } else {
                ZStack {
                    Rectangle()
                        .fill(.quaternary)

                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .clipped()
            }
        }
    }
}

