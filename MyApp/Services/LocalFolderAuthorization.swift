import AppKit
import Foundation

@MainActor
final class LocalFolderAuthorization {
    static let shared = LocalFolderAuthorization()

    private let storageKey = "securityScopedFolderBookmarks"
    private var activeURLs: [URL] = []

    private init() {
        restoreBookmarks()
    }

    func chooseFolder(onNavigate: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Grant Access"
        panel.message = "Choose a folder or drive FileBridge can browse."

        if panel.runModal() == .OK, let url = panel.url {
            saveBookmark(for: url)
            _ = url.startAccessingSecurityScopedResource()
            activeURLs.append(url)
            onNavigate(url)
        }
    }

    private func saveBookmark(for url: URL) {
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return
        }

        var bookmarks = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Data] ?? [:]
        bookmarks[url.path] = bookmark
        UserDefaults.standard.set(bookmarks, forKey: storageKey)
    }

    private func restoreBookmarks() {
        let bookmarks = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: Data] ?? [:]
        for bookmark in bookmarks.values {
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else {
                continue
            }
            if url.startAccessingSecurityScopedResource() {
                activeURLs.append(url)
            }
        }
    }
}
