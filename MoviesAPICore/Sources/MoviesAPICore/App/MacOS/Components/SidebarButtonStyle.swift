#if os(macOS)
//
//  SidebarButtonStyle.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/19/26.
//

import SwiftUI

struct SidebarButtonStyle: ButtonStyle {
    @State private var isVisuallyPressed = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isVisuallyPressed ? 0.99 : 1)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    isVisuallyPressed = true
                } else {
                    Task {
                        try? await Task.sleep(for: .milliseconds(90))
                        isVisuallyPressed = false
                    }
                }
            }
            .animation(.easeOut(duration: 0.12), value: isVisuallyPressed)
    }
}

#endif
