import Foundation
import Observation

@MainActor
@Observable
final class FileBrowserState {
    private let fileSystemService: LocalFileSystemService

    var currentURL: URL
    var items: [FileItem] = [] {
        didSet { resortItems() }
    }
    private(set) var sortedItems: [FileItem] = []
    var selection: Set<FileItem.ID> = []
    var sort: FileSort = .name {
        didSet { resortItems() }
    }
    var isAscending = true {
        didSet { resortItems() }
    }
    var viewMode: BrowserViewMode = .list
    var errorMessage: String?

    private var backHistory: [URL] = []
    private var forwardHistory: [URL] = []

    init(initialURL: URL) {
        self.currentURL = initialURL
        self.fileSystemService = LocalFileSystemService()
        refresh()
    }

    var canGoBack: Bool { !backHistory.isEmpty }
    var canGoForward: Bool { !forwardHistory.isEmpty }

    var selectedItem: FileItem? {
        guard let selectedID = selection.first else { return nil }
        return items.first { $0.id == selectedID }
    }

    func refresh() {
        do {
            items = try fileSystemService.items(in: currentURL)
            errorMessage = nil
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
    }

    func navigate(to url: URL) {
        guard url != currentURL else {
            refresh()
            return
        }

        backHistory.append(currentURL)
        forwardHistory.removeAll()
        currentURL = url
        selection.removeAll()
        refresh()
    }

    func goBack() {
        guard let previousURL = backHistory.popLast() else { return }
        forwardHistory.append(currentURL)
        currentURL = previousURL
        selection.removeAll()
        refresh()
    }

    func goForward() {
        guard let nextURL = forwardHistory.popLast() else { return }
        backHistory.append(currentURL)
        currentURL = nextURL
        selection.removeAll()
        refresh()
    }

    func goUp() {
        navigate(to: currentURL.deletingLastPathComponent())
    }

    func open(_ item: FileItem) {
        guard item.isDirectory else { return }
        navigate(to: item.url)
    }

    func toggleSort(_ newSort: FileSort) {
        if sort == newSort {
            isAscending.toggle()
        } else {
            sort = newSort
            isAscending = true
        }
    }

    func setSort(_ newSort: FileSort, ascending: Bool) {
        sort = newSort
        isAscending = ascending
    }

    private func resortItems() {
        sortedItems = items.sorted { first, second in
            if first.isDirectory != second.isDirectory {
                return first.isDirectory
            }

            let comparison: ComparisonResult
            switch sort {
            case .name:
                comparison = first.name.localizedStandardCompare(second.name)
            case .fileType:
                comparison = FilePresentation.fileExtension(for: first.name)
                    .localizedStandardCompare(FilePresentation.fileExtension(for: second.name))
            case .size:
                comparison = compare(first.size ?? 0, second.size ?? 0)
            case .modifiedDate:
                comparison = compare(first.modifiedDate ?? .distantPast, second.modifiedDate ?? .distantPast)
            }

            if comparison == .orderedSame {
                return first.name.localizedStandardCompare(second.name) == .orderedAscending
            }
            return isAscending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }

    private func compare<T: Comparable>(_ first: T, _ second: T) -> ComparisonResult {
        if first == second { return .orderedSame }
        return first < second ? .orderedAscending : .orderedDescending
    }
}
