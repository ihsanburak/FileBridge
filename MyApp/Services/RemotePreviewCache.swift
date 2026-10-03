import Foundation

actor RemotePreviewCache {
    static let shared = RemotePreviewCache()

    private let directoryURL: URL
    private var cachedFiles: Set<URL> = []

    init() {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileBridgePreviewCache", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        let expiration = Date().addingTimeInterval(-60 * 60 * 24)
        for file in files {
            let modifiedDate = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            if modifiedDate ?? .distantPast < expiration {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    func previewURL(for item: RemoteFileItem, using service: SFTPService) async throws -> URL {
        let fileExtension = FilePresentation.fileExtension(for: item.name)
        let destination = directoryURL
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        try await service.downloadPreviewFile(at: item.path, to: destination)
        cachedFiles.insert(destination)
        removeOldCachedFiles(keeping: destination)
        return destination
    }

    func remove(_ url: URL) {
        cachedFiles.remove(url)
        try? FileManager.default.removeItem(at: url)
    }

    private func removeOldCachedFiles(keeping url: URL) {
        let filesToRemove = cachedFiles.filter { $0 != url }
        for cachedFile in filesToRemove {
            try? FileManager.default.removeItem(at: cachedFile)
            cachedFiles.remove(cachedFile)
        }
    }
}
