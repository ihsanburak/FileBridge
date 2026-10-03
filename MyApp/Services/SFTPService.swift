import CSSH2
import Darwin
import Foundation
import SSH2

enum SFTPServiceError: LocalizedError {
    case invalidPort
    case unableToResolveHost
    case unableToConnect
    case sessionInitialization
    case handshakeFailed
    case authenticationFailed
    case sftpInitializationFailed
    case notConnected
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPort:
            "The port number is invalid."
        case .unableToResolveHost:
            "The server address could not be resolved."
        case .unableToConnect:
            "Unable to reach the server. Check the host, port, and network connection."
        case .sessionInitialization:
            "Unable to create the SSH session."
        case .handshakeFailed:
            "The SSH handshake failed."
        case .authenticationFailed:
            "Authentication failed. Check the username and password."
        case .sftpInitializationFailed:
            "The server did not allow an SFTP session."
        case .notConnected:
            "The SFTP connection is no longer active."
        case let .operationFailed(message):
            message
        }
    }
}

final class SFTPService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.filebridge.sftp")
    private var socketFileDescriptor: Int32 = -1
    private var session: OpaquePointer?
    private var sftp: OpaquePointer?

    init() {
        try? SSH2.initialize()
    }

    deinit {
        disconnectSynchronously()
    }

    func beginConnection(
        to profile: SFTPConnectionProfile,
        onSSHHandshake: @escaping @Sendable () -> Void = {}
    ) async throws -> HostKeyInfo {
        try await perform {
            self.disconnectSynchronously()
            guard (1...65_535).contains(profile.port) else {
                throw SFTPServiceError.invalidPort
            }

            self.socketFileDescriptor = try self.openSocket(host: profile.host, port: profile.port)
            onSSHHandshake()
            guard let session = libssh2_session_init_ex(nil, nil, nil, nil) else {
                self.disconnectSynchronously()
                throw SFTPServiceError.sessionInitialization
            }
            self.session = session

            guard libssh2_session_handshake(session, self.socketFileDescriptor) == 0 else {
                self.disconnectSynchronously()
                throw SFTPServiceError.handshakeFailed
            }

            guard let fingerprint = libssh2_hostkey_hash(session, Int32(LIBSSH2_HOSTKEY_HASH_SHA256)) else {
                self.disconnectSynchronously()
                throw SFTPServiceError.handshakeFailed
            }

            var keyLength = 0
            var keyType = Int32(LIBSSH2_HOSTKEY_TYPE_UNKNOWN)
            _ = libssh2_session_hostkey(session, &keyLength, &keyType)
            let fingerprintData = Data(bytes: fingerprint, count: 32)
            return HostKeyInfo(
                host: profile.host,
                port: profile.port,
                keyType: Self.hostKeyType(keyType),
                sha256Fingerprint: "SHA256:\(fingerprintData.base64EncodedString().replacingOccurrences(of: "=", with: ""))"
            )
        }
    }

    func authenticate(username: String, password: String) async throws -> String {
        try await perform {
            guard let session = self.session else {
                throw SFTPServiceError.notConnected
            }

            let authenticationResult = username.withCString { usernamePointer in
                password.withCString { passwordPointer in
                    libssh2_userauth_password_ex(
                        session,
                        usernamePointer,
                        UInt32(username.utf8.count),
                        passwordPointer,
                        UInt32(password.utf8.count),
                        nil
                    )
                }
            }
            guard authenticationResult == 0 else {
                self.disconnectSynchronously()
                throw SFTPServiceError.authenticationFailed
            }

            guard let sftp = libssh2_sftp_init(session) else {
                self.disconnectSynchronously()
                throw SFTPServiceError.sftpInitializationFailed
            }
            self.sftp = sftp
            return try self.realPath(".")
        }
    }

    func items(in path: String) async throws -> [RemoteFileItem] {
        try await perform {
            guard let sftp = self.sftp else {
                throw SFTPServiceError.notConnected
            }

            let handle = path.withCString { pointer in
                libssh2_sftp_open_ex(sftp, pointer, UInt32(path.utf8.count), 0, 0, Int32(LIBSSH2_SFTP_OPENDIR))
            }
            guard let handle else {
                throw self.sftpOperationError(defaultMessage: "Unable to open this remote folder.")
            }
            defer { _ = libssh2_sftp_close_handle(handle) }

            var results: [RemoteFileItem] = []
            var nameBuffer = [CChar](repeating: 0, count: 4_096)
            var longEntryBuffer = [CChar](repeating: 0, count: 4_096)

            while true {
                var attributes = LIBSSH2_SFTP_ATTRIBUTES()
                let count = libssh2_sftp_readdir_ex(
                    handle,
                    &nameBuffer,
                    nameBuffer.count,
                    &longEntryBuffer,
                    longEntryBuffer.count,
                    &attributes
                )
                if count == 0 {
                    break
                }
                if count < 0 {
                    throw self.sftpOperationError(defaultMessage: "Unable to read this remote folder.")
                }

                let name = String(cString: nameBuffer)
                guard name != "." && name != ".." else {
                    continue
                }

                let itemPath = path == "/" ? "/\(name)" : "\(path)/\(name)"
                let isDirectory = (attributes.permissions & 0o170000) == 0o040000
                let hasSize = (attributes.flags & 0x00000001) != 0
                let hasModifiedDate = (attributes.flags & 0x00000008) != 0
                results.append(
                    RemoteFileItem(
                        path: itemPath,
                        name: name,
                        isDirectory: isDirectory,
                        size: hasSize ? Int64(bitPattern: attributes.filesize) : nil,
                        modifiedDate: hasModifiedDate
                            ? Date(timeIntervalSince1970: TimeInterval(attributes.mtime))
                            : nil
                    )
                )
            }

            return results
        }
    }

    func createDirectory(at path: String) async throws {
        try await perform {
            guard let sftp = self.sftp else {
                throw SFTPServiceError.notConnected
            }
            let result = path.withCString { pointer in
                libssh2_sftp_mkdir_ex(sftp, pointer, UInt32(path.utf8.count), 0o755)
            }
            guard result == 0 else {
                throw self.sftpOperationError(defaultMessage: "Unable to create the remote folder.")
            }
        }
    }

    func rename(from source: String, to destination: String) async throws {
        try await perform {
            guard let sftp = self.sftp else {
                throw SFTPServiceError.notConnected
            }
            let result = source.withCString { sourcePointer in
                destination.withCString { destinationPointer in
                    libssh2_sftp_rename_ex(
                        sftp,
                        sourcePointer,
                        UInt32(source.utf8.count),
                        destinationPointer,
                        UInt32(destination.utf8.count),
                        Int(LIBSSH2_SFTP_RENAME_OVERWRITE | LIBSSH2_SFTP_RENAME_ATOMIC | LIBSSH2_SFTP_RENAME_NATIVE)
                    )
                }
            }
            guard result == 0 else {
                throw self.sftpOperationError(defaultMessage: "Unable to rename the remote item.")
            }
        }
    }

    func delete(_ item: RemoteFileItem) async throws {
        try await perform {
            guard let sftp = self.sftp else {
                throw SFTPServiceError.notConnected
            }
            let result = item.path.withCString { pointer in
                item.isDirectory
                    ? libssh2_sftp_rmdir_ex(sftp, pointer, UInt32(item.path.utf8.count))
                    : libssh2_sftp_unlink_ex(sftp, pointer, UInt32(item.path.utf8.count))
            }
            guard result == 0 else {
                throw self.sftpOperationError(
                    defaultMessage: item.isDirectory
                        ? "Unable to delete the remote folder. It may not be empty."
                        : "Unable to delete the remote file."
                )
            }
        }
    }

    /// Copies one remote file into an app-managed temporary location for inspection only.
    /// This is intentionally separate from future user-initiated transfer support.
    func downloadPreviewFile(at remotePath: String, to localURL: URL) async throws {
        try await perform {
            guard let sftp = self.sftp else {
                throw SFTPServiceError.notConnected
            }

            let handle = remotePath.withCString { pointer in
                libssh2_sftp_open_ex(
                    sftp,
                    pointer,
                    UInt32(remotePath.utf8.count),
                    UInt(LIBSSH2_FXF_READ),
                    0,
                    Int32(LIBSSH2_SFTP_OPENFILE)
                )
            }
            guard let handle else {
                throw self.sftpOperationError(defaultMessage: "Unable to read the remote file for preview.")
            }
            defer { _ = libssh2_sftp_close_handle(handle) }

            FileManager.default.createFile(atPath: localURL.path, contents: nil)
            let fileHandle = try FileHandle(forWritingTo: localURL)
            defer { try? fileHandle.close() }

            var buffer = [CChar](repeating: 0, count: 32_768)
            while true {
                let count = buffer.withUnsafeMutableBufferPointer { pointer in
                    libssh2_sftp_read(handle, pointer.baseAddress, pointer.count)
                }
                if count == 0 {
                    break
                }
                if count < 0 {
                    throw self.sftpOperationError(defaultMessage: "Unable to read the remote file for preview.")
                }

                let chunk = buffer.withUnsafeBytes { rawBuffer in
                    Data(rawBuffer.prefix(Int(count)))
                }
                try fileHandle.write(contentsOf: chunk)
            }
        }
    }

    func disconnect() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.disconnectSynchronously()
                continuation.resume()
            }
        }
    }

    private func realPath(_ path: String) throws -> String {
        guard let sftp else {
            throw SFTPServiceError.notConnected
        }
        var buffer = [CChar](repeating: 0, count: 4_096)
        let result = path.withCString { pointer in
            libssh2_sftp_symlink_ex(
                sftp,
                pointer,
                UInt32(path.utf8.count),
                &buffer,
                UInt32(buffer.count),
                Int32(LIBSSH2_SFTP_REALPATH)
            )
        }
        guard result > 0 else {
            throw sftpOperationError(defaultMessage: "Unable to determine the remote home folder.")
        }
        return String(cString: buffer)
    }

    private func sftpOperationError(defaultMessage: String) -> SFTPServiceError {
        guard let sftp else {
            return .notConnected
        }
        switch libssh2_sftp_last_error(sftp) {
        case UInt(LIBSSH2_FX_PERMISSION_DENIED):
            return .operationFailed("Permission denied by the remote server.")
        case UInt(LIBSSH2_FX_NO_SUCH_FILE), UInt(LIBSSH2_FX_NO_SUCH_PATH):
            return .operationFailed("The remote path does not exist.")
        case UInt(LIBSSH2_FX_CONNECTION_LOST), UInt(LIBSSH2_FX_NO_CONNECTION):
            return .operationFailed("The connection to the remote server was lost.")
        default:
            return .operationFailed(defaultMessage)
        }
    }

    private func disconnectSynchronously() {
        if let sftp {
            _ = libssh2_sftp_shutdown(sftp)
            self.sftp = nil
        }
        if let session {
            _ = libssh2_session_disconnect_ex(session, Int32(SSH_DISCONNECT_BY_APPLICATION), "FileBridge disconnect", "")
            _ = libssh2_session_free(session)
            self.session = nil
        }
        if socketFileDescriptor >= 0 {
            Darwin.close(socketFileDescriptor)
            socketFileDescriptor = -1
        }
    }

    private func openSocket(host: String, port: Int) throws -> Int32 {
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var addressInfo: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, String(port), &hints, &addressInfo) == 0, let firstAddress = addressInfo else {
            throw SFTPServiceError.unableToResolveHost
        }
        defer { freeaddrinfo(firstAddress) }

        var candidate: UnsafeMutablePointer<addrinfo>? = firstAddress
        while let address = candidate {
            let descriptor = socket(address.pointee.ai_family, address.pointee.ai_socktype, address.pointee.ai_protocol)
            if descriptor >= 0 {
                var timeout = timeval(tv_sec: 15, tv_usec: 0)
                _ = withUnsafePointer(to: &timeout) { pointer in
                    setsockopt(
                        descriptor,
                        SOL_SOCKET,
                        SO_RCVTIMEO,
                        pointer,
                        socklen_t(MemoryLayout<timeval>.size)
                    )
                }
                _ = withUnsafePointer(to: &timeout) { pointer in
                    setsockopt(
                        descriptor,
                        SOL_SOCKET,
                        SO_SNDTIMEO,
                        pointer,
                        socklen_t(MemoryLayout<timeval>.size)
                    )
                }
                if Darwin.connect(descriptor, address.pointee.ai_addr, address.pointee.ai_addrlen) == 0 {
                    return descriptor
                }
                Darwin.close(descriptor)
            }
            candidate = address.pointee.ai_next
        }

        throw SFTPServiceError.unableToConnect
    }

    private func perform<T: Sendable>(_ operation: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    continuation.resume(returning: try operation())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func hostKeyType(_ value: Int32) -> String {
        switch value {
        case Int32(LIBSSH2_HOSTKEY_TYPE_RSA):
            "RSA"
        case Int32(LIBSSH2_HOSTKEY_TYPE_DSS):
            "DSA"
        case Int32(LIBSSH2_HOSTKEY_TYPE_ECDSA_256):
            "ECDSA P-256"
        case Int32(LIBSSH2_HOSTKEY_TYPE_ECDSA_384):
            "ECDSA P-384"
        case Int32(LIBSSH2_HOSTKEY_TYPE_ECDSA_521):
            "ECDSA P-521"
        case Int32(LIBSSH2_HOSTKEY_TYPE_ED25519):
            "Ed25519"
        default:
            "Unknown"
        }
    }
}
