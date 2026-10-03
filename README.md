# FileBridge

**FileBridge** is a simple, native macOS SFTP client for secure dual-pane file browsing and server management over SSH.

FileBridge is a Captain21 application. Its workflow is deliberately focused:

```
Local Mac  <---- SFTP / SSH ---->  Remote Server
```

## Current capabilities

- Native SwiftUI macOS interface with independent local and remote file panes.
- Real SFTP browsing through SSH using SSH2/libssh2.
- Password authentication, saved connection profiles, and Keychain-backed remembered passwords.
- Strict SSH host-key verification: first-time hosts require explicit trust; changed host keys block the connection.
- Remote navigation, refresh, sortable list/grid views, create folder, rename, and delete.
- Local and remote file metadata, file-type icons, and optional inspector/image previews.
- A compact connection visualizer that reflects real connection and remote-operation activity.

## Security and privacy

- Passwords are stored only in macOS Keychain when the user chooses to remember them.
- Connection profiles contain only a UUID, name, host, port, and username.
- FileBridge has no telemetry, analytics, advertising, credential backend, or cloud synchronization.
- Network traffic is initiated only for user-selected SFTP/SSH servers.

See [SECURITY.md](SECURITY.md) for the security model and reporting guidance.

## Build from source

### Requirements

- Xcode with the macOS SDK required by the project.
- macOS 27 or later, matching the current project deployment target.

### Steps

1. Clone this repository.
2. Open `Untitled Project.xcodeproj` in Xcode.
3. Resolve the Swift Package dependencies if prompted.
4. Select the `MyApp` scheme and a Mac run destination.
5. Build and run.

## Connecting to a server

1. Choose **New Connection**.
2. Enter a connection name, host, port, username, and password.
3. On the first connection, independently verify the displayed SHA-256 SSH host fingerprint, then choose **Trust & Connect**.
4. Browse the remote filesystem in the right pane.

Never accept a changed SSH host key without verifying the change through a trusted channel.

## Dependencies

- [SSH2 0.2.0](https://github.com/mfcollins3/libssh2-apple), used for the Swift/libssh2 bridge.
- libssh2, used for the SSH and SFTP protocol implementation.
- OpenSSL 0.2.0, used by the package dependency stack.

Third-party notices are available in the application’s **Acknowledgements** screen and in the resolved package sources.

## Distribution status

The source is ready to build in Xcode. A public DMG release should be signed with a **Developer ID Application** certificate and notarized by Apple before general distribution, so macOS Gatekeeper can validate it.

## Support

Captain21: [captain21.support@gmail.com](mailto:captain21.support@gmail.com)
