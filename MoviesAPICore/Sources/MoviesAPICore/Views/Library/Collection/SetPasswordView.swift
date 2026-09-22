//
//  SetPasswordView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/21/26.
//

import SwiftUI

struct SetPasswordView: View {

    let onConfirmPassword: ([Int]) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var enteredPassword: [Int] = []
    @State private var confirmation: [Int] = []
    @State private var isConfirming = false
    @State private var passwordsDoNotMatch = false

    private var currentEntry: [Int] {
        isConfirming ? confirmation : enteredPassword
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(isConfirming ? "Re-Enter Password" : "Set Password")
                .font(.title2.bold())

            PasswordCircles(password: currentEntry)

            if passwordsDoNotMatch {
                Text("Passwords do not match. Try again.")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            PasswordNumpadView(
                password: currentEntry,
                append: append,
                removeLastDigit: removeLastDigit
            )

            Button(isConfirming ? "Set Password" : "Continue") {
                advance()
            }
            .buttonStyle(.borderedProminent)
            .disabled(currentEntry.count != 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("Password")
    }

    private func append(_ number: Int) {
        guard currentEntry.count < 4 else { return }

        passwordsDoNotMatch = false
        if isConfirming {
            confirmation.append(number)
        } else {
            enteredPassword.append(number)
        }
    }

    private func removeLastDigit() {
        passwordsDoNotMatch = false
        if isConfirming {
            confirmation.removeLast()
        } else {
            enteredPassword.removeLast()
        }
    }

    private func advance() {
        guard currentEntry.count == 4 else { return }

        if isConfirming {
            guard confirmation == enteredPassword else {
                confirmation.removeAll()
                passwordsDoNotMatch = true
                return
            }

            onConfirmPassword(enteredPassword)
            dismiss()
        } else {
            isConfirming = true
        }
    }
}



#Preview {
    SetPasswordView() { _ in }
}
