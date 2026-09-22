//
//  LibraryCollectionDetailView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/21/26.
//

import SwiftUI
import SwiftData

/// Each Collection Gets its
struct LibraryCollectionDetailView: View {
    @Environment(TMDBManager.self) private var tmdbManager
    @Environment(PlaybackSession.self) private var playbackSession
    @Environment(\.modelContext) var modelContext

    var collection: Collection

    private let columns = [
        GridItem(
            .adaptive(minimum: 120, maximum: 180),
            spacing: 16
        )
    ]

    @State private var doesPasswordMatch = false
    @State private var searchResult: KTSearchResult?
    @State private var goToDetail = false
    @State private var resolveTask: Task<Void, Never>?
    @State private var resolvingItem: CollectionItem?
    @State private var isResolving = false
    @State private var error: String?
    @State private var showError = false

    var body: some View {
        switch collection.passwordCollectionState {
        case .none:
            contentView
        case .password(let password):
            if doesPasswordMatch {
                contentView
            } else {
                PasswordView(password: password, onPasswordValid: {
                    doesPasswordMatch = true
                })
            }
        }
    }

    private var contentView: some View {
        ScrollView {
            LazyVGrid(
                columns: columns,
                alignment: .leading,
                spacing: 20
            ) {
                ForEach(collection.results) { result in
                    LibraryCollectionRow(result: result)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playbackSession.stop()
                            resolve(result)
                        }
                        .overlay {
                            if resolvingItem?.resultId == result.resultId,
                               resolvingItem?.mediaType == result.mediaType {
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(.black.opacity(0.1))
                            }
                        }
                }
            }
            .padding()
        }
        .navigationTitle(collection.name)
        .navigationDestination(isPresented: $goToDetail) {
            if let searchResult {
                WatchDetailView(result: searchResult)
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(error ?? "Unknown Error")
            )
        }
        .onDisappear {
            resolveTask?.cancel()
            resolveTask = nil
        }
        .toolbar {
#if os(macOS)
            ToolbarSpacer(.flexible)
#endif
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Toggle("Hide Library Cover Image", isOn: Binding(
                        get: { collection.hidesCoverImage },
                        set: { isOn in
                            collection.hidesCoverImage = isOn
                            try? modelContext.save()
                        }
                    ))
                } label: {
                    Image(systemName: "ellipsis")
                }
                NavigationLink {
                    passwordNavigation
                } label: {
                    Image(systemName: "lock")
                }
            }
        }
    }

    @ViewBuilder
    private var passwordNavigation: some View {
        switch collection.passwordCollectionState {
        case .none:
            SetPasswordView { password in
                collection.passwordCollectionState = .password(password)
                doesPasswordMatch = true
            }
        case .password(let currentPassword):
            PasswordChangeView(currentPassword: currentPassword) { password in
                if let password {
                    collection.passwordCollectionState = .password(password)
                    doesPasswordMatch = true
                } else {
                    collection.passwordCollectionState = .none
                    doesPasswordMatch = true
                }
            }
        }
    }

    private func resolve(_ item: CollectionItem) {
        guard !isResolving else { return }

        resolveTask = Task {
            resolvingItem = item
            isResolving = true
            defer {
                isResolving = false
                resolvingItem = nil
            }

            do {
                try await tmdbManager.search(item.name)
                searchResult = tmdbManager.searchResults.first {
                    $0.id == item.resultId && $0.mediaType.rawValue == item.mediaType
                }
                goToDetail = searchResult != nil
                tmdbManager.clearSearchResults()
            } catch {
                self.error = error.localizedDescription
                showError = true
            }
        }
    }
}

private struct LibraryCollectionRow: View {
    var result: CollectionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CollectionImageView(imagePath: result.posterPath)
                .clipShape(.rect(cornerRadius: 10))

            Text(result.name)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(result.mediaType.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CollectionImageView: View {

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
