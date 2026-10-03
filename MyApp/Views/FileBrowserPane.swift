import SwiftUI

struct FileBrowserPane: View {
    @Bindable var browser: FileBrowserState
    let title: LocalizedStringKey
    let onSelectionChange: (FileItem?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            LocalBrowserToolbar(
                title: title,
                canGoBack: browser.canGoBack,
                canGoForward: browser.canGoForward,
                selectedItem: browser.selectedItem,
                sort: browser.sort,
                isAscending: browser.isAscending,
                viewMode: browser.viewMode,
                onBack: browser.goBack,
                onForward: browser.goForward,
                onUp: browser.goUp,
                onRefresh: browser.refresh,
                onOpen: openSelectedItem,
                onSort: browser.toggleSort,
                onViewModeChange: { browser.viewMode = $0 }
            )

            LocalBreadcrumbBar(currentURL: browser.currentURL, onNavigate: browser.navigate)
            Divider()

            if let errorMessage = browser.errorMessage {
                ContentUnavailableView(
                    "Unable to Open Folder",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if browser.viewMode == .list {
                LocalFileTable(
                    items: browser.sortedItems,
                    selection: $browser.selection,
                    onOpen: browser.open,
                    onSort: browser.setSort
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LocalFileGrid(
                    items: browser.sortedItems,
                    selection: $browser.selection,
                    onOpen: browser.open
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: browser.selection) { _, _ in
            onSelectionChange(browser.selectedItem)
        }
    }

    private func openSelectedItem() {
        guard let item = browser.selectedItem else { return }
        browser.open(item)
    }
}

private struct LocalBrowserToolbar: View {
    let title: LocalizedStringKey
    let canGoBack: Bool
    let canGoForward: Bool
    let selectedItem: FileItem?
    let sort: FileSort
    let isAscending: Bool
    let viewMode: BrowserViewMode
    let onBack: () -> Void
    let onForward: () -> Void
    let onUp: () -> Void
    let onRefresh: () -> Void
    let onOpen: () -> Void
    let onSort: (FileSort) -> Void
    let onViewModeChange: (BrowserViewMode) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button(action: onBack) { Image(systemName: "chevron.left") }
                    .disabled(!canGoBack)
                    .help("Back")

                Button(action: onForward) { Image(systemName: "chevron.right") }
                    .disabled(!canGoForward)
                    .help("Forward")

                Button(action: onUp) { Image(systemName: "arrow.up") }
                    .help("Go to Parent Folder")

                Button(action: onRefresh) { Image(systemName: "arrow.clockwise") }
                    .help("Refresh")

                BrowserSortMenu(sort: sort, isAscending: isAscending, onSort: onSort)
                    .help("Sort Files")

                Menu {
                    ForEach(BrowserViewMode.allCases) { mode in
                        Button {
                            onViewModeChange(mode)
                        } label: {
                            Label(mode.label, systemImage: mode.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: viewMode.systemImage)
                }
                .help("Change View")

                Button(action: onOpen) { Image(systemName: "folder") }
                    .disabled(selectedItem?.isDirectory != true)
                    .help("Open Selected Folder")
            }
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BrowserSortMenu: View {
    let sort: FileSort
    let isAscending: Bool
    let onSort: (FileSort) -> Void

    var body: some View {
        Menu {
            ForEach(FileSort.allCases) { option in
                Button {
                    onSort(option)
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if sort == option {
                            Image(systemName: isAscending ? "chevron.up" : "chevron.down")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: sort == .name && isAscending
                ? "arrow.up.arrow.down"
                : "arrow.up.arrow.down.circle.fill")
        }
    }
}

private struct LocalBreadcrumbBar: View {
    let currentURL: URL
    let onNavigate: (URL) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                Button("/") { onNavigate(URL(fileURLWithPath: "/")) }
                    .buttonStyle(.plain)

                ForEach(pathComponents, id: \.url) { component in
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button(component.name) { onNavigate(component.url) }
                        .buttonStyle(.plain)
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pathComponents: [(name: String, url: URL)] {
        var result: [(name: String, url: URL)] = []
        var accumulatedURL = URL(fileURLWithPath: "/")

        for component in currentURL.pathComponents.dropFirst() {
            accumulatedURL.appendPathComponent(component, isDirectory: true)
            result.append((component, accumulatedURL))
        }
        return result
    }
}

private struct LocalFileTable: View {
    let items: [FileItem]
    @Binding var selection: Set<FileItem.ID>
    let onOpen: (FileItem) -> Void
    let onSort: (FileSort, Bool) -> Void
    @State private var sortOrder: [KeyPathComparator<FileItem>] = [KeyPathComparator(\.name)]

    var body: some View {
        Table(items, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { item in
                Label(item.name, systemImage: FilePresentation.iconName(name: item.name, isDirectory: item.isDirectory))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .onTapGesture(count: 2) {
                        if item.isDirectory { onOpen(item) }
                    }
                    .contextMenu {
                        if item.isDirectory {
                            Button("Open") { onOpen(item) }
                        }
                        Divider()
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([item.url])
                        }
                    }
            }
            .width(min: 150, ideal: 240)

            TableColumn("Size", value: \.sortSize) { item in
                Text(item.isDirectory ? "—" : item.sizeDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 72, ideal: 90, max: 110)

            TableColumn("Modified Date", value: \.sortModifiedDate) { item in
                if let modifiedDate = item.modifiedDate {
                    Text(modifiedDate, format: .dateTime.year().month().day().hour().minute())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .width(min: 120, ideal: 145, max: 170)
        }
        .onChange(of: sortOrder) { _, newOrder in
            guard let comparator = newOrder.first else { return }
            let selectedSort: FileSort
            if comparator.keyPath == \FileItem.name {
                selectedSort = .name
            } else if comparator.keyPath == \FileItem.sortSize {
                selectedSort = .size
            } else {
                selectedSort = .modifiedDate
            }
            onSort(selectedSort, comparator.order == .forward)
        }
    }
}

private struct LocalFileGrid: View {
    let items: [FileItem]
    @Binding var selection: Set<FileItem.ID>
    let onOpen: (FileItem) -> Void

    private let columns = [GridItem(.adaptive(minimum: 88, maximum: 130), spacing: 14)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    BrowserGridItem(
                        name: item.name,
                        iconName: FilePresentation.iconName(name: item.name, isDirectory: item.isDirectory),
                        isSelected: selection.contains(item.id)
                    )
                    .onTapGesture { selection = [item.id] }
                    .onTapGesture(count: 2) {
                        if item.isDirectory { onOpen(item) }
                    }
                    .contextMenu {
                        if item.isDirectory {
                            Button("Open") { onOpen(item) }
                        }
                        Divider()
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([item.url])
                        }
                    }
                }
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BrowserGridItem: View {
    let name: String
    let iconName: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 32))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? .white : Color.accentColor)
                .frame(height: 40)

            Text(name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 84)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .background(isSelected ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 6))
    }
}
