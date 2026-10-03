import Foundation

struct SFTPConnectionProfile: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String

    init(id: UUID = UUID(), name: String, host: String, port: Int = 22, username: String) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
    }

    var endpoint: String { "\(username)@\(host):\(port)" }
    var passwordKeychainAccount: String { id.uuidString }
}

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case awaitingHostTrust(HostKeyInfo)
    case authenticating(SFTPConnectionProfile)
    case connected(SFTPConnectionProfile)
    case failed(String)

    var statusDescription: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting…"
        case .awaitingHostTrust: "Awaiting Host Verification"
        case .authenticating: "Authenticating…"
        case let .connected(profile): "Connected to \(profile.name)"
        case .failed: "Connection Failed"
        }
    }
}

struct HostKeyInfo: Equatable, Identifiable, Sendable {
    let host: String
    let port: Int
    let keyType: String
    let sha256Fingerprint: String

    var id: String { "\(host):\(port):\(sha256Fingerprint)" }
}

enum ConnectionProgress: Equatable, Sendable {
    case idle, tcpConnecting, sshHandshake, verifyingHostKey, awaitingHostTrust, authenticatingAndStartingSFTP, connected
}

enum ConnectionVisualizerActivity: Equatable, Sendable {
    case idle, request, response, uploading, downloading
}

struct RemoteFileItem: Identifiable, Hashable, Sendable {
    let path: String
    let name: String
    let isDirectory: Bool
    let size: Int64?
    let modifiedDate: Date?

    var id: String { path }
    var sortSize: Int64 { size ?? -1 }
    var sortModifiedDate: Date { modifiedDate ?? .distantPast }
    var sizeDescription: String {
        guard let size else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
