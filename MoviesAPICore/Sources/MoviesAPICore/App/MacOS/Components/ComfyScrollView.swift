#if os(macOS)
//
//  ComfyScrollView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/18/26.
//

import SwiftUI

struct ComfyScrollView<Content: View>: View {
    ///  take in content of what needs to be shown
    
    var noPadding: Bool = false
    var spacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        List {
            Section {
                VStack(spacing: spacing) {
                    content()
                }
                .if(!noPadding) {
                    $0.padding()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}
#endif
