import Foundation

struct LocalFileSystemService {
    private let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .fileSizeKey,
        .contentModificationDateKey,
        .isHiddenKey
    ]

    func items(in directory: URL) throws -> [FileItem] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: resourceKeys) else {
                return nil
            }

            return FileItem(
                url: url,
                name: url.lastPathComponent,
                isDirectory: values.isDirectory ?? false,
                size: values.fileSize.map(Int64.init),
                modifiedDate: values.contentModificationDate
            )
        }
    }
}
