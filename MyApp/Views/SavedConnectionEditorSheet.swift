import SwiftUI

struct SavedConnectionEditorSheet: View {
    let profile: SFTPConnectionProfile
    let onSave: (SFTPConnectionProfile) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var host: String
    @State private var port: Int
    @State private var username: String

    init(
        profile: SFTPConnectionProfile,
        onSave: @escaping (SFTPConnectionProfile) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.profile = profile
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: profile.name)
        _host = State(initialValue: profile.host)
        _port = State(initialValue: profile.port)
        _username = State(initialValue: profile.username)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Edit SFTP Connection", systemImage: "server.rack")
                .font(.title2)

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
            }
            .textFieldStyle(.roundedBorder)

            Text("Passwords are managed separately in Keychain.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save") {
                    onSave(
                        SFTPConnectionProfile(
                            id: profile.id,
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            host: host.trimmingCharacters(in: .whitespacesAndNewlines),
                            port: port,
                            username: username.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !(1...65_535).contains(port)
                )
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
