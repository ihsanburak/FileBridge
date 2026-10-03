import Foundation
import Observation

@MainActor
@Observable
final class ConnectionManager {
    let service = SFTPService()

    var state: ConnectionState = .disconnected
    var connectionProgress: ConnectionProgress = .idle
    var visualizerActivity: ConnectionVisualizerActivity = .idle
    private(set) var activeProfile: SFTPConnectionProfile?
    var savedProfiles: [SFTPConnectionProfile] = []
    var remoteHomeDirectory = "/"

    private let keychainService = KeychainService()
    private let knownHostsService = KnownHostsService()
    private var pendingProfile: SFTPConnectionProfile?
    private var pendingPassword = ""
    private var pendingRememberPassword = false

    init() {
        savedProfiles = Self.loadProfiles()
    }

    func connect(profile: SFTPConnectionProfile, password: String, rememberPassword: Bool) async {
        state = .connecting
        connectionProgress = .tcpConnecting
        visualizerActivity = .request
        activeProfile = profile
        pendingProfile = profile
        pendingPassword = password
        pendingRememberPassword = rememberPassword

        do {
            let hostKey = try await service.beginConnection(to: profile) { [weak self] in
                Task { @MainActor [weak self] in self?.connectionProgress = .sshHandshake }
            }
            connectionProgress = .verifyingHostKey
            if let trustedFingerprint = knownHostsService.trustedFingerprint(for: profile.host, port: profile.port) {
                guard trustedFingerprint == hostKey.sha256Fingerprint else {
                    await service.disconnect()
                    clearPendingConnection()
                    state = .failed("Security warning: the SSH host key changed. Connection was blocked.")
                    return
                }
                await finishAuthentication()
            } else {
                state = .awaitingHostTrust(hostKey)
                connectionProgress = .awaitingHostTrust
            }
        } catch {
            await service.disconnect()
            clearPendingConnection()
            state = .failed(error.localizedDescription)
        }
    }

    func connectSaved(_ profile: SFTPConnectionProfile) async -> Bool {
        do {
            guard let password = try keychainService.password(for: profile) else {
                return false
            }
            await connect(profile: profile, password: password, rememberPassword: false)
            return true
        } catch {
            return false
        }
    }

    func trustAndConnect(_ hostKey: HostKeyInfo) async {
        knownHostsService.trust(hostKey)
        connectionProgress = .verifyingHostKey
        await finishAuthentication()
    }

    func cancelPendingConnection() async {
        await service.disconnect()
        clearPendingConnection()
        state = .disconnected
        connectionProgress = .idle
        visualizerActivity = .idle
        activeProfile = nil
    }

    func disconnect() async {
        await service.disconnect()
        clearPendingConnection()
        state = .disconnected
        connectionProgress = .idle
        visualizerActivity = .idle
        activeProfile = nil
        remoteHomeDirectory = "/"
    }

    func update(profile: SFTPConnectionProfile) {
        savedProfiles.removeAll { $0.id == profile.id }
        savedProfiles.append(profile)
        savedProfiles.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        persistProfiles()
    }

    func forgetSavedPassword(for profile: SFTPConnectionProfile) {
        try? keychainService.deletePassword(for: profile)
    }

    func delete(profile: SFTPConnectionProfile, deleteCredential: Bool = true) {
        savedProfiles.removeAll { $0.id == profile.id }
        persistProfiles()
        if deleteCredential { try? keychainService.deletePassword(for: profile) }
    }

    private func finishAuthentication() async {
        guard let profile = pendingProfile else {
            state = .failed("The connection request expired.")
            return
        }

        state = .authenticating(profile)
        connectionProgress = .authenticatingAndStartingSFTP

        do {
            remoteHomeDirectory = try await service.authenticate(username: profile.username, password: pendingPassword)
            if pendingRememberPassword {
                try keychainService.save(password: pendingPassword, for: profile)
            }
            update(profile: profile)
            clearPendingConnection()
            state = .connected(profile)
            connectionProgress = .connected
            visualizerActivity = .idle
        } catch {
            await service.disconnect()
            clearPendingConnection()
            state = .failed(error.localizedDescription)
        }
    }

    private func persistProfiles() {
        guard let data = try? JSONEncoder().encode(savedProfiles) else { return }
        UserDefaults.standard.set(data, forKey: "savedSFTPConnectionProfiles")
    }

    private static func loadProfiles() -> [SFTPConnectionProfile] {
        guard let data = UserDefaults.standard.data(forKey: "savedSFTPConnectionProfiles"),
              let profiles = try? JSONDecoder().decode([SFTPConnectionProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    private func clearPendingConnection() {
        pendingProfile = nil
        pendingPassword = ""
        pendingRememberPassword = false
    }
}
