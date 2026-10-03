import SwiftUI

struct SavedConnectionAuthenticationSheet: View {
    let profile: SFTPConnectionProfile
    let onConnect: (String, Bool) -> Void
    let onCancel: () -> Void

    @State private var password = ""
    @State private var rememberPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                FileBridgeLogo(size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name).font(.title3.weight(.semibold))
                    Text(profile.username).font(.callout).foregroundStyle(.secondary)
                }
            }

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Toggle("Remember Password in Keychain", isOn: $rememberPassword)

            HStack {
                Spacer()
                Button("Cancel") {
                    password = ""
                    onCancel()
                }
                Button("Connect") {
                    let submittedPassword = password
                    password = ""
                    onConnect(submittedPassword, rememberPassword)
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onDisappear { password = "" }
    }
}
