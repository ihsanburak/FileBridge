import SwiftUI

struct ConnectionSheet: View {
    let initialProfile: SFTPConnectionProfile?
    let onConnect: (SFTPConnectionProfile, String, Bool) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var host = ""
    @State private var port = 22
    @State private var username = ""
    @State private var password = ""
    @State private var rememberPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                FileBridgeLogo(size: 46)
                Text(initialProfile == nil ? "New SFTP Connection" : "Edit SFTP Connection")
                    .font(.title2)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Connection Name")
                    TextField("My Server", text: $name)
                }
                GridRow {
                    Text("Host / IP")
                    TextField("server.example.com", text: $host)
                }
                GridRow {
                    Text("Port")
                    TextField("22", value: $port, format: .number)
                        .frame(width: 90, alignment: .leading)
                }
                GridRow {
                    Text("Username")
                    TextField("username", text: $username)
                }
                GridRow {
                    Text("Password")
                    SecureField("Password", text: $password)
                }
            }
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
                    onConnect(
                        SFTPConnectionProfile(
                            id: initialProfile?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
                            port: port,
                            username: username.trimmingCharacters(in: .whitespacesAndNewlines)
                        ),
                        submittedPassword,
                        rememberPassword
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || !(1...65_535).contains(port))
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear {
            guard let initialProfile else {
                return
            }
            name = initialProfile.name
            host = initialProfile.host
            port = initialProfile.port
            username = initialProfile.username
            password = ""
            rememberPassword = false
        }
        .onDisappear {
            password = ""
        }
    }
}

struct HostKeyVerificationView: View {
    let hostKey: HostKeyInfo
    let onCancel: () -> Void
    let onTrust: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The authenticity of this host cannot be established.")
                .font(.title3.weight(.semibold))

            Text("Verify the fingerprint with your server administrator before trusting this host.")
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Host").foregroundStyle(.secondary)
                    Text(hostKey.host)
                }
                GridRow {
                    Text("Port").foregroundStyle(.secondary)
                    Text("\(hostKey.port)")
                }
                GridRow {
                    Text("Key Type").foregroundStyle(.secondary)
                    Text(hostKey.keyType)
                }
                GridRow {
                    Text("Fingerprint").foregroundStyle(.secondary)
                    Text(hostKey.sha256Fingerprint)
                        .textSelection(.enabled)
                        .font(.system(.body, design: .monospaced))
                }
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Trust & Connect", action: onTrust)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 540)
    }
}
