#if os(macOS)
//
//  MacOSRootSidebar.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/19/26.
//

import SwiftUI

struct MacOSRootSidebar: View {

    @Environment(TMDBManager.self) var tmdbmanager

    @Binding var selectedTab: MacOSTab
    @Binding var path: NavigationPath

    @State private var search: String = ""
    @State private var hasInteractedWithSearch: Bool = false
    @FocusState private var isSearchBarFocused: Bool
    @Namespace private var selectionNamespace

    @State private var error: String?
    @State private var showError: Bool = false

    @State private var isSearching: Bool = false

    var body: some View {
        VStack {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $search)
                    .focused($isSearchBarFocused)
                    .textFieldStyle(.plain)
                    .onTapGesture {
                        hasInteractedWithSearch = true
                    }
                    .onSubmit {
                        if isSearching { return }
                        Task {
                            isSearching = true
                            defer { isSearching = false }
                            do {
                                try await tmdbmanager.search(search)
                                path.append(MacOSRoute.searchResults)
                            } catch {
                                self.error = error.localizedDescription
                                self.showError = true
                            }
                        }
                    }
            }
            .padding(8)
            .padding(.leading, 2)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 6)

            ComfyScrollView(noPadding: true, spacing: 8) {
                ForEach(MacOSTab.allCases, id: \.self) { tab in
                    Button {
                        path.removeLast(path.count)
                        selectedTab = tab
                    } label: {
                        SidebarRowView(
                            tab: tab,
                        )
                        .padding(6)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hex: "#DAD2D6")!.mix(with: .black, by: 0.15))
                                    .opacity(0.4)
                                    .matchedGeometryEffect(id: "selected", in: selectionNamespace)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SidebarButtonStyle())
                    .animation(.snappy, value: selectedTab)
                    .allowsHitTesting(selectedTab != tab)
                }
            }
        }
        .coordinateSpace(name: "sidebar")
        .frame(width: 240)
        .padding(.top, 48)
        .clipped()
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(error, default: "Unknown Error")")
            )
        }
    }
}

struct SidebarRowView: View {

    let tab: MacOSTab
    var font: Font = .system(size: 14, weight: .regular, design: .rounded)

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(tab.color)
                .frame(width: 25, height: 25)
                .overlay {
                    ZStack {
                        tab.icon
                            .foregroundStyle(.black)
                            .fontWeight(.black)
                            .scaleEffect(1.04)

                        tab.icon
                            .foregroundStyle(.white)
                            .fontWeight(.black)
                            .scaleEffect(tab.primaryScale)
                    }
                }

            Text(tab.rawValue)
                .font(font)

            Spacer()
        }
    }
}

#endif
