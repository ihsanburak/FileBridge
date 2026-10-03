import Foundation

struct KnownHostsService {
    private let storageKey = "trustedSFTPHosts"

    func trustedFingerprint(for host: String, port: Int) -> String? {
        storedHosts[hostKey(host: host, port: port)]
    }

    func trust(_ hostKeyInfo: HostKeyInfo) {
        var hosts = storedHosts
        hosts[hostKey(host: hostKeyInfo.host, port: hostKeyInfo.port)] = hostKeyInfo.sha256Fingerprint
        UserDefaults.standard.set(hosts, forKey: storageKey)
    }

    private var storedHosts: [String: String] {
        UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }

    private func hostKey(host: String, port: Int) -> String {
        "\(host.lowercased()):\(port)"
    }
}
