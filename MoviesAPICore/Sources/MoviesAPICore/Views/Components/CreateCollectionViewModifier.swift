//
//  CreateCollectionViewModifier.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/22/26.
//

import SwiftUI
import SwiftData

struct CreateCollectionViewModifier: ViewModifier {

    @Environment(\.modelContext) var modelContext

    @Binding var showCreateCollection: Bool
    @Binding var collectionName: String
    @Binding var collectionResultToAdd: KTSearchResult?

    func body(content: Content) -> some View {
        content
            .alert("Create Collection", isPresented: $showCreateCollection) {
                TextField("Collection Name", text: $collectionName)

                Button("Cancel", role: .cancel) {
                    collectionName = ""
                    collectionResultToAdd = nil
                }

                Button("Create") {
                    guard
                        !collectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        let result = collectionResultToAdd
                            else { return }

                    let item = CollectionItem(
                        resultId: Int(result.id),
                        name: result.title ?? result.name ?? "",
                        mediaType: result.mediaType.rawValue,
                        posterPath: result.posterPath
                    )

                    let collection = Collection(
                        name: collectionName.trimmingCharacters(in: .whitespacesAndNewlines),
                        results: [item]
                    )

                    modelContext.insert(collection)

                    collectionName = ""
                    collectionResultToAdd = nil
                }
            } message: {
                Text("Enter a name for your new collection.")
            }
    }
}
