import Foundation

enum AppInfo {
    static let name = "FileBridge"
    static let studioName = "Captain21"
    static let supportEmail = "captain21.support@gmail.com"
    static let websiteURL: URL? = nil
    static let privacyPolicyURL: URL? = nil
    static let githubURL: URL? = nil

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Not available"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Not available"
    }

    static var versionDescription: String {
        "Version \(version) (Build \(build))"
    }

    static var architecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "Unknown"
        #endif
    }

    static var macOSDescription: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    static var diagnosticInfo: String {
        "\(name) \(version) (\(build))\nmacOS \(macOSDescription)\nArchitecture: \(architecture)\nProtocol: SFTP/SSH"
    }
}
