//
//  HistoryRow.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/15/26.
//

import SwiftUI

struct HistoryRow: View {
    let history: History

    var body: some View {
        HStack(spacing: 14) {
            artwork

            VStack(alignment: .leading, spacing: 5) {
                Text(history.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    mediaDescription

                    Text("•")

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let seconds = max(0, Int(context.date.timeIntervalSince(history.watchedAt)))
                        let minutes = seconds / 60
                        let hours = minutes / 60
                        let days = hours / 24

                        Group {
                            if seconds < 60 {
                                Text("\(seconds)s ago")
                            } else if minutes < 60 {
                                Text("\(minutes)m ago")
                            } else if hours < 24 {
                                Text("\(hours)h ago")
                            } else {
                                Text("\(days)d ago")
                            }
                        }
                        .contentTransition(.numericText())
                        .animation(.snappy, value: seconds)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private var artwork: some View {
        Group {
            if let posterPath = history.posterPath,
               let url = URL(
                string: "https://image.tmdb.org/t/p/w500\(posterPath)"
               ) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    posterPlaceholder
                }
            } else {
                posterPlaceholder
            }
        }
        .frame(width: 48, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var posterPlaceholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(
                    systemName: history.mediaType == .movie
                    ? "film"
                    : "play.rectangle"
                )
                .font(.title3)
                .foregroundStyle(.secondary)
            }
    }
    
    @ViewBuilder
    private var mediaDescription: some View {
        if let season = history.season,
           let episode = history.episode {
            Text("S\(season) E\(episode)")
        } else {
            Text("Movie")
        }
    }
}
