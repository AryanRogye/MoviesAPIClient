//
//  PasswordCircles.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/21/26.
//

import SwiftUI

struct PasswordCircles: View {

    let password: [Int]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                Image(systemName: index < password.count ? "circle.fill" : "circle")
            }
        }
        .font(.title3)
    }
}
