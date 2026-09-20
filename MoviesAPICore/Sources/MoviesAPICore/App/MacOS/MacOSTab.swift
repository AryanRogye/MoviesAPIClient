#if os(macOS)
//
//  MacOSTab.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/18/26.
//

import SwiftUI

enum MacOSTab: String, CaseIterable {
    case home
    case library
    case history
    case settings

    var icon: Image {
        switch self {
        case .home:
            Image(systemName: "house.fill")
        case .library:
            Image(systemName: "building.columns.fill")
        case .history:
            Image(systemName: "clock")
        case .settings:
            Image(systemName: "gearshape.fill")
        }
    }

    var primaryScale: CGFloat {
        1
    }

    var color: AnyShapeStyle {
        switch self {
        case .settings:
            AnyShapeStyle(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: "#BABABA")!.mix(with: .black, by: 0.01), location: 0.0),
                        .init(color: Color(hex: "#BABABA")!.mix(with: .black, by: 0.05), location: 0.5),
                        .init(color: Color(hex: "#BABABA")!.mix(with: .black, by: 0.01), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .home:
            AnyShapeStyle(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: "#FF2659")!.mix(with: .white, by: 0.3), location: 0.0),
                        .init(color: Color(hex: "#FF2659")!.mix(with: .white, by: 0.3), location: 0.5),
                        .init(color: Color(hex: "#FF2659")!.mix(with: .white, by: 0.1), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .history:
            AnyShapeStyle(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(hex: "#4DA3FF")!.mix(with: .white, by: 0.20), location: 0.0),
                        .init(color: Color(hex: "#2785E8")!, location: 0.5),
                        .init(color: Color(hex: "#1261B8")!, location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .library:
            AnyShapeStyle(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.black.mix(with: .white, by: 0.5), location: 0.0),
                        .init(color: Color.black.mix(with: .white, by: 0.3), location: 0.5),
                        .init(color: Color.black.mix(with: .white, by: 0.1), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}
#endif
