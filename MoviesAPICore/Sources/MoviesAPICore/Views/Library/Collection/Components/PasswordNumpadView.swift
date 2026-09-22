//
//  PasswordNumberButton.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/21/26.
//

import SwiftUI

struct PasswordNumpadView: View {

    let password: [Int]
    let append: (Int) -> Void
    let removeLastDigit: () -> Void

    private let columns = Array(
        repeating: GridItem(.flexible()),
        count: 3
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(1...9, id: \.self) { number in
                numberButton(number)
            }

            Color.clear
            numberButton(0)

            Button {
                removeLastDigit()
            } label: {
                Image(systemName: "delete.left")
                    .font(.title2)
                    .frame(width: 76, height: 76)
            }
            .buttonStyle(.plain)
            .disabled(password.isEmpty)
        }
        .frame(maxWidth: 320)
    }

    private func numberButton(_ number: Int) -> some View {
        PasswordNumberButton(
            number: number,
            append: append,
            disabled: password.count == 4
        )
    }
}

private struct PasswordNumberButton: View {

    let number: Int
    let append: (Int) -> Void
    let disabled: Bool

    var body: some View {
        Button {
            append(number)
        } label: {
            Text(number, format: .number)
                .font(.title2)
                .frame(width: 76, height: 76)
                .glassEffect(.clear, in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
