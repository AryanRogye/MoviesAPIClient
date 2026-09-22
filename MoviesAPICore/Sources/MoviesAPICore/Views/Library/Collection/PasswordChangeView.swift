//
//  PasswordChangeView.swift
//  MoviesAPICore
//
//  Created by Aryan Rogye on 9/21/26.
//

import SwiftUI

struct PasswordChangeView: View {

    let currentPassword: [Int]
    let onConfirmPassword: ([Int]?) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var passwordsDoNotMatch: Bool = false
    @State private var enteredPassword: [Int] = []

    @State private var passwordsMatch: Bool = false

    var body: some View {
        if passwordsMatch {

            VStack {
                Button {
                    onConfirmPassword(nil)
                    dismiss()
                } label: {
                    Text("Remove Password Protection")
                        .font(.title2.bold())
                }
                .buttonStyle(.borderedProminent)

                NavigationLink {
                    SetPasswordView { password in
                        onConfirmPassword(password)
                        dismiss()
                    }
                } label: {
                    Text("Change Password")
                        .font(.title2.bold())
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .navigationTitle("Password Config")

        } else {
            VStack(spacing: 24) {
                Text("Enter Your Current Password")
                    .font(.title2.bold())

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
    }

    private func advance() {
        guard enteredPassword.count == 4 else { return }

        if currentPassword == enteredPassword {
            passwordsMatch = true
            return
        } else {
            passwordsMatch = false
            passwordsDoNotMatch = true
        }
    }

    private func append(_ number: Int) {
        guard enteredPassword.count < 4 else { return }

        passwordsMatch = false
        passwordsDoNotMatch = false

        enteredPassword.append(number)
    }

    private func removeLastDigit() {
        passwordsDoNotMatch = false
        enteredPassword.removeLast()
    }

}
