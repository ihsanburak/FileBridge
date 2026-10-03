import Foundation
import Observation

@MainActor
@Observable
final class RemoteFileBrowserState {
    var currentPath = "/"
    var items: [RemoteFileItem] = [] {
        didSet { resortItems() }
    }
    private(set) var sortedItems: [RemoteFileItem] = []
    var selection: Set<RemoteFileItem.ID> = []
    var sort: FileSort = .name {
        didSet { resortItems() }
    }
    var isAscending = true {
        didSet { resortItems() }
    }
    var viewMode: BrowserViewMode = .list
    var errorMessage: String?
    private(set) var visualizerActivity: ConnectionVisualizerActivity = .idle

    private var activityResetTask: Task<Void, Never>?
    private var backHistory: [String] = []
    private var forwardHistory: [String] = []
    private var service: SFTPService?

    var canGoBack: Bool { !backHistory.isEmpty }
    var canGoForward: Bool { !forwardHistory.isEmpty }

    var selectedItem: RemoteFileItem? {
        guard let id = selection.first else { return nil }
        return items.first { $0.id == id }
    }

    func configure(service: SFTPService, homeDirectory: String) async {
        self.service = service
        currentPath = homeDirectory
        backHistory.removeAll()
        forwardHistory.removeAll()
        selection.removeAll()
        await refresh()
    }

    func reset() {
        service = nil
        currentPath = "/"
        items = []
        selection.removeAll()
        errorMessage = nil
        backHistory.removeAll()
        forwardHistory.removeAll()
        activityResetTask?.cancel()
        visualizerActivity = .idle
    }

    func refresh() async {
        guard let service else { return }
        beginNetworkActivity()

        do {
            items = try await service.items(in: currentPath)
            errorMessage = nil
            completeNetworkActivity()
        } catch {
            errorMessage = error.localizedDescription
            visualizerActivity = .idle
        }
    }

    func navigate(to path: String) async {
        guard path != currentPath else {
            await refresh()
            return
        }
        backHistory.append(currentPath)
        forwardHistory.removeAll()
        currentPath = normalized(path)
        selection.removeAll()
        await refresh()
    }

    func open(_ item: RemoteFileItem) async {
        guard item.isDirectory else { return }
        await navigate(to: item.path)
    }

    func goBack() async {
        guard let previousPath = backHistory.popLast() else { return }
        forwardHistory.append(currentPath)
        currentPath = previousPath
        selection.removeAll()
        await refresh()
    }

    func goForward() async {
        guard let nextPath = forwardHistory.popLast() else { return }
        backHistory.append(currentPath)
        currentPath = nextPath
        selection.removeAll()
        await refresh()
    }

    func goUp() async {
        let parent = (currentPath as NSString).deletingLastPathComponent
        await navigate(to: parent.isEmpty ? "/" : parent)
    }

    func createDirectory(named name: String) async {
        guard let service, !name.isEmpty else { return }
        beginNetworkActivity()
        do {
            let path = currentPath == "/" ? "/\(name)" : "\(currentPath)/\(name)"
            try await service.createDirectory(at: path)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            visualizerActivity = .idle
        }
    }

    func rename(_ item: RemoteFileItem, to name: String) async {
        guard let service, !name.isEmpty else { return }
        beginNetworkActivity()
        do {
            let destination = (item.path as NSString).deletingLastPathComponent + "/\(name)"
            try await service.rename(from: item.path, to: destination)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            visualizerActivity = .idle
        }
    }

    func delete(_ item: RemoteFileItem) async {
        guard let service else { return }
        beginNetworkActivity()
        do {
            try await service.delete(item)
            selection.removeAll()
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
            visualizerActivity = .idle
        }
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

    private func beginNetworkActivity() {
        activityResetTask?.cancel()
        visualizerActivity = .request
    }

    private func completeNetworkActivity() {
        activityResetTask?.cancel()
        visualizerActivity = .response
        activityResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            guard !Task.isCancelled else { return }
            self?.visualizerActivity = .idle
        }
    }

    private func normalized(_ path: String) -> String {
        let standardized = (path as NSString).standardizingPath
        return standardized.hasPrefix("/") ? standardized : "/\(standardized)"
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
