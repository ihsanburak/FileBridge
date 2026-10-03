import Foundation

struct FileItem: Identifiable, Hashable, Sendable {
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64?
    let modifiedDate: Date?

    var id: URL { url }

    var sortSize: Int64 { size ?? -1 }
    var sortModifiedDate: Date { modifiedDate ?? .distantPast }

    var sizeDescription: String {
        guard let size else {
            return "—"
        }

        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
