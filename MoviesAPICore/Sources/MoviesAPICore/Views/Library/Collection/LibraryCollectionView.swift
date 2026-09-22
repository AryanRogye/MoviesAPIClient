//
//  LibraryCollectionView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/18/26.
//

import SwiftUI
import SwiftData

struct LibraryCollectionView: View {
    @Environment(TMDBManager.self) var tmdbManager
    @Environment(PlaybackSession.self) var playbackSession

    @Query var favorites: [Favorite]
    @Query var collection: [Collection]

    let rows: [GridItem] = [
        GridItem(.fixed(180), spacing: 12),
        GridItem(.fixed(180), spacing: 12),
    ]

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var searchResult: KTSearchResult?
    @State private var goToDetail: Bool = false

    @State private var resolveTask: Task<Void, Never>?
    @State private var resolvingFavorite: Favorite?
    @State private var isResolving: Bool = false

    var body: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: rows,spacing: 12) {
                ForEach(collection, id: \.id) { collection in
                    NavigationLink {
                        LibraryCollectionDetailView(collection: collection)
                    } label: {
                        VStack(alignment: .leading) {
                            CollectionArtworkView(paths: collection.coverImagePaths)
                            Text(collection.name)
                        }
                        .frame(width: 110, height: 165)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
        .navigationDestination(isPresented: $goToDetail) {
            if let searchResult {
                WatchDetailView(result: searchResult)
            }
        }
        .onDisappear {
            resolveTask?.cancel()
            resolveTask = nil
        }
    }
}


private struct CollectionArtworkView: View {

    let paths: [String]

    let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0)
    ]

    var body: some View {
        Group {
            switch paths.count {
            case 0:
                EmptyView()

            case 1:
                oneImage

            case 2:
                twoImages

            case 3:
                threeImages

            default:
                fourImages
            }
        }
        .clipShape(.rect(cornerRadius: 12))
    }

    private var oneImage: some View {
        GeometryReader { geo in
            CollectionImageView(imagePath: paths[0])
                .frame(
                    width: geo.size.width,
                    height: geo.size.height
                )
                .clipped()
        }
    }

    private var twoImages: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                CollectionImageView(imagePath: paths[0])
                    .frame(
                        width: geo.size.width,
                        height: geo.size.height / 2
                    )
                    .clipped()
                CollectionImageView(imagePath: paths[1])
                    .frame(
                        width: geo.size.width,
                        height: geo.size.height / 2
                    )
                    .clipped()
            }
        }
    }

    private var threeImages: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                CollectionImageView(imagePath: paths[0])
                    .frame(
                        width: geo.size.width / 2,
                        height: geo.size.height
                    )

                VStack(spacing: 0) {
                    CollectionImageView(imagePath: paths[1])
                        .frame(
                            width: geo.size.width / 2,
                            height: geo.size.height / 2
                        )

                    CollectionImageView(imagePath: paths[2])
                        .frame(
                            width: geo.size.width / 2,
                            height: geo.size.height / 2
                        )
                }
            }
        }

    }

    private var fourImages: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(paths.prefix(4).indices, id: \.self) { index in
                CollectionImageView(imagePath: paths[index])
                    .aspectRatio(2 / 3, contentMode: .fill)
            }
        }
        .clipShape(.rect(cornerRadius: 12))
    }

    private struct CollectionImageView: View {

        let imagePath: String?

        var body: some View {
            Group {
                if let imagePath,
                   let url = URL(
                    string: "https://image.tmdb.org/t/p/w500\(imagePath)"
                   ) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                ProgressView()
                            }
                    }
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .clipped()
        }
    }

}
