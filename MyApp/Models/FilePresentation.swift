import Foundation

enum FileSort: String, CaseIterable, Identifiable, Sendable {
    case name = "Name"
    case fileType = "File Type"
    case size = "Size"
    case modifiedDate = "Modified Date"

    var id: Self { self }
}

enum BrowserViewMode: String, CaseIterable, Identifiable, Sendable {
    case list
    case grid

    var id: Self { self }

    var label: String {
        switch self {
        case .list: "List View"
        case .grid: "Icon View"
        }
    }

    var systemImage: String {
        switch self {
        case .list: "list.bullet"
        case .grid: "square.grid.2x2"
        }
    }
}

enum FilePresentation {
    nonisolated static func fileExtension(for name: String) -> String {
        (name as NSString).pathExtension.lowercased()
    }

    nonisolated static func typeName(name: String, isDirectory: Bool) -> String {
        guard !isDirectory else { return "Folder" }
        let fileExtension = fileExtension(for: name)
        return fileExtension.isEmpty ? "Document" : fileExtension.uppercased() + " File"
    }

    nonisolated static func iconName(name: String, isDirectory: Bool) -> String {
        guard !isDirectory else { return "folder.fill" }

        return switch fileExtension(for: name) {
        case "jpg", "jpeg", "png", "heic", "heif", "webp", "gif", "tif", "tiff", "bmp":
            "photo"
        case "mov", "mp4", "m4v", "avi", "mkv", "webm":
            "film"
        case "mp3", "m4a", "aac", "wav", "aiff", "flac", "ogg":
            "music.note"
        case "pdf":
            "doc.richtext"
        case "zip", "tar", "gz", "bz2", "xz", "7z", "rar":
            "archivebox"
        case "swift", "c", "h", "m", "mm", "cpp", "cc", "java", "js", "ts", "py", "rb", "go", "rs", "php", "html", "css", "json", "xml", "yml", "yaml", "sh":
            "chevron.left.forwardslash.chevron.right"
        case "txt", "rtf", "md", "log", "csv", "doc", "docx", "pages":
            "doc.text"
        case "dmg", "iso", "img":
            "externaldrive"
        default:
            "doc"
        }
    }

    nonisolated static func isImage(name: String, isDirectory: Bool) -> Bool {
        guard !isDirectory else { return false }
        return ["jpg", "jpeg", "png", "heic", "heif", "webp", "gif", "tif", "tiff", "bmp"]
            .contains(fileExtension(for: name))
    }
}
