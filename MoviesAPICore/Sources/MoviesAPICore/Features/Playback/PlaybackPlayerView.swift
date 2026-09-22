//
//  PlaybackPlayerView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/22/26.
//

import SwiftUI

struct PlaybackPlayerView: View {

    @Environment(PlaybackSession.self) var playbackSession
    let returnToPlayback: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: returnToPlayback) {
                HStack(spacing: 10) {

                    PlaybackImageView(playbackSession: playbackSession)

                    PlaybackBody(playbackSession: playbackSession)

                    Spacer()

                    icon
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .padding(.horizontal, 8)
        .contextMenu {
            Button("Close", role: .destructive, action: playbackSession.stop)
        } preview: {
            HStack(spacing: 10) {

                PlaybackImageView(playbackSession: playbackSession)

                PlaybackBody(playbackSession: playbackSession)

                Spacer()

                icon
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
        }
    }

    private var icon: some View {
        Image(systemName: "play.fill")
            .font(.title3)
            .padding(.horizontal, 5)
    }
}

private struct PlaybackImageView: View {

    let playbackSession: PlaybackSession

    var body: some View {
        if let posterPath = playbackSession.playback?.posterPath,
           let posterURL = URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)") {
            AsyncImage(url: posterURL) { image in
                image
                    .resizable()
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 30, height: 30)
            .clipShape(.rect(cornerRadius: 5))
        }
    }
}

private struct PlaybackBody: View {

    let playbackSession: PlaybackSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(playbackSession.playback?.title ?? "Now Playing")
                .font(.callout)
                .lineLimit(1)
            if let tvShow = playbackSession.playback?.episode {
                Text("S\(tvShow.seasonNumber) E\(tvShow.episode.episodeNumber)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
