//
//  PasswordView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/21/26.
//

import SwiftUI

struct PasswordView: View {

    let password: [Int]
    let onPasswordValid: () -> Void

    @State private var passwordsDoNotMatch: Bool = false
    @State private var enteredPassword: [Int] = []

    var body: some View {
        VStack(spacing: 24) {
            passwordHeader

            PasswordCircles(password: enteredPassword)

            if passwordsDoNotMatch {
                Text("Password does not match. Try again.")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            PasswordNumpadView(
                password: enteredPassword,
                append: append,
                removeLastDigit: removeLastDigit
            )

            Button("Enter") {
                advance()
            }
            .buttonStyle(.borderedProminent)
            .disabled(enteredPassword.count != 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("Password")
    }

    private var passwordHeader: some View {
        Text("Enter Password")
            .font(.title2.bold())
    }

    private func advance() {
        guard enteredPassword.count == 4 else { return }

        if password == enteredPassword {
            onPasswordValid()
            return
        } else {
            passwordsDoNotMatch = true
        }
    }

    private func append(_ number: Int) {
        guard enteredPassword.count < 4 else { return }

        passwordsDoNotMatch = false

        enteredPassword.append(number)
    }

    private func removeLastDigit() {
        passwordsDoNotMatch = false
        enteredPassword.removeLast()
    }
}
