# FileBridge Security

FileBridge is designed for direct, user-initiated SFTP file management.

## Connection security

- FileBridge uses SFTP over SSH.
- SSH host identities are verified before authentication. A first-time host requires an explicit trust decision; a changed host key blocks the connection.
- Passwords are stored only in macOS Keychain when the user enables **Remember Password in Keychain**. Connection profiles persist only a UUID, display name, host, port, and username.
- FileBridge does not store plaintext passwords, private keys, or authentication tokens in profiles, preferences, logs, or diagnostics.

## Privacy and network use

- FileBridge has no Captain21 credential backend and does not synchronize connection credentials.
- It has no analytics, telemetry, advertising SDKs, automatic diagnostic uploads, or update-check network requests.
- Network connections are made only to servers the user explicitly selects for SFTP/SSH functionality.
- FileBridge does not sell or collect connection credentials.

## Diagnostics

The diagnostic-copy feature includes only application version, build, macOS version, architecture, protocol, and generic error categories. It excludes passwords, Keychain data, private keys, saved server addresses, usernames, and paths.

## Reporting a concern

Report security concerns to captain21.support@gmail.com. Do not include passwords or private keys in a report.

FileBridge cannot guarantee absolute security; keep macOS and server software updated and verify SSH host fingerprints through a trusted channel.
