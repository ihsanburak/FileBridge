import SwiftUI

struct RemoteFileBrowserPane: View {
    @Bindable var browser: RemoteFileBrowserState
    let profile: SFTPConnectionProfile?
    let connectionState: ConnectionState
    let onSelectionChange: (RemoteFileItem?) -> Void

    @State private var pathText = ""
    @State private var isShowingNewFolder = false
    @State private var folderName = ""
    @State private var itemToRename: RemoteFileItem?
    @State private var renameText = ""
    @State private var itemToDelete: RemoteFileItem?

    var body: some View {
        VStack(spacing: 0) {
            RemoteBrowserToolbar(
                title: profile?.name ?? "Remote Server",
                canGoBack: browser.canGoBack,
                canGoForward: browser.canGoForward,
                isConnected: profile != nil,
                sort: browser.sort,
                isAscending: browser.isAscending,
                viewMode: browser.viewMode,
                onBack: { Task { await browser.goBack() } },
                onForward: { Task { await browser.goForward() } },
                onUp: { Task { await browser.goUp() } },
                onRefresh: { Task { await browser.refresh() } },
                onNewFolder: {
                    folderName = ""
                    isShowingNewFolder = true
                },
                onSort: browser.toggleSort,
                onViewModeChange: { browser.viewMode = $0 }
            )

            RemotePathBar(
                currentPath: browser.currentPath,
                pathText: $pathText,
                isConnected: profile != nil,
                onNavigate: { path in Task { await browser.navigate(to: path) } }
            )

            Divider()

            RemoteBrowserContent(
                items: browser.sortedItems,
                selection: $browser.selection,
                state: connectionState,
                errorMessage: browser.errorMessage,
                viewMode: browser.viewMode,
                onOpen: { item in Task { await browser.open(item) } },
                onRename: {
                    itemToRename = $0
                    renameText = $0.name
                },
                onDelete: { itemToDelete = $0 },
                onSort: browser.setSort
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { pathText = browser.currentPath }
        .onChange(of: browser.currentPath) { _, newPath in pathText = newPath }
        .onChange(of: browser.selection) { _, _ in onSelectionChange(browser.selectedItem) }
        .alert("New Remote Folder", isPresented: $isShowingNewFolder) {
            TextField("Folder Name", text: $folderName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                Task { await browser.createDirectory(named: folderName) }
            }
        }
        .alert("Rename Remote Item", isPresented: Binding(
            get: { itemToRename != nil },
            set: { if !$0 { itemToRename = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { itemToRename = nil }
            Button("Rename") {
                if let itemToRename {
                    Task { await browser.rename(itemToRename, to: renameText) }
                }
                itemToRename = nil
            }
        }
        .confirmationDialog(
            itemToDelete.map { "Delete \"\($0.name)\"?" } ?? "",
            isPresented: Binding(
                get: { itemToDelete != nil },
                set: { if !$0 { itemToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let itemToDelete {
                    Task { await browser.delete(itemToDelete) }
                }
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) { itemToDelete = nil }
        } message: {
            Text("This action will permanently delete the remote item.")
        }
    }
}

private struct RemoteBrowserToolbar: View {
    let title: String
    let canGoBack: Bool
    let canGoForward: Bool
    let isConnected: Bool
    let sort: FileSort
    let isAscending: Bool
    let viewMode: BrowserViewMode
    let onBack: () -> Void
    let onForward: () -> Void
    let onUp: () -> Void
    let onRefresh: () -> Void
    let onNewFolder: () -> Void
    let onSort: (FileSort) -> Void
    let onViewModeChange: (BrowserViewMode) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button(action: onBack) { Image(systemName: "chevron.left") }
                    .disabled(!isConnected || !canGoBack)
                    .help("Back")
                Button(action: onForward) { Image(systemName: "chevron.right") }
                    .disabled(!isConnected || !canGoForward)
                    .help("Forward")
                Button(action: onUp) { Image(systemName: "arrow.up") }
                    .disabled(!isConnected)
                    .help("Go to Parent Folder")
                Button(action: onRefresh) { Image(systemName: "arrow.clockwise") }
                    .disabled(!isConnected)
                    .help("Refresh")

                BrowserSortMenu(sort: sort, isAscending: isAscending, onSort: onSort)
                    .disabled(!isConnected)
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
                .disabled(!isConnected)
                .help("Change View")

                Button(action: onNewFolder) { Image(systemName: "folder.badge.plus") }
                    .disabled(!isConnected)
                    .help("New Folder")
            }
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

private struct RemotePathBar: View {
    let currentPath: String
    @Binding var pathText: String
    let isConnected: Bool
    let onNavigate: (String) -> Void

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: "folder").foregroundStyle(.secondary)

                TextField("/", text: $pathText)
                    .textFieldStyle(.plain)
                    .font(.caption.monospaced())
                    .onSubmit {
                        guard pathText.hasPrefix("/") else { return }
                        onNavigate(pathText)
                    }
                    .disabled(!isConnected)

                Button {
                    guard pathText.hasPrefix("/") else { return }
                    onNavigate(pathText)
                } label: {
                    Image(systemName: "arrow.right.circle")
                }
                .buttonStyle(.plain)
                .disabled(!isConnected || !pathText.hasPrefix("/"))
                .help("Open Path")
            }

            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(breadcrumbs, id: \.path) { crumb in
                        Button(crumb.title) { onNavigate(crumb.path) }
                            .buttonStyle(.plain)
                            .disabled(!isConnected)
                        if crumb.path != currentPath {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.caption2)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private var breadcrumbs: [(title: String, path: String)] {
        guard currentPath != "/" else { return [("/", "/")] }

        var result: [(title: String, path: String)] = [("/", "/")]
        var path = ""
        for component in currentPath.split(separator: "/") {
            path += "/\(component)"
            result.append((String(component), path))
        }
        return result
    }
}

private struct RemoteBrowserContent: View {
    let items: [RemoteFileItem]
    @Binding var selection: Set<RemoteFileItem.ID>
    let state: ConnectionState
    let errorMessage: String?
    let viewMode: BrowserViewMode
    let onOpen: (RemoteFileItem) -> Void
    let onRename: (RemoteFileItem) -> Void
    let onDelete: (RemoteFileItem) -> Void
    let onSort: (FileSort, Bool) -> Void

    var body: some View {
        if case .connected = state {
            Group {
                if viewMode == .list {
                    RemoteFileTable(
                        items: items,
                        selection: $selection,
                        onOpen: onOpen,
                        onRename: onRename,
                        onDelete: onDelete,
                        onSort: onSort
                    )
                } else {
                    RemoteFileGrid(
                        items: items,
                        selection: $selection,
                        onOpen: onOpen,
                        onRename: onRename,
                        onDelete: onDelete
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if let errorMessage {
                    ContentUnavailableView(
                        "Unable to Open Remote Folder",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                }
            }
        } else {
            RemoteConnectionStatus(state: state)
        }
    }
}

private struct RemoteFileTable: View {
    let items: [RemoteFileItem]
    @Binding var selection: Set<RemoteFileItem.ID>
    let onOpen: (RemoteFileItem) -> Void
    let onRename: (RemoteFileItem) -> Void
    let onDelete: (RemoteFileItem) -> Void
    let onSort: (FileSort, Bool) -> Void
    @State private var sortOrder: [KeyPathComparator<RemoteFileItem>] = [KeyPathComparator(\.name)]

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
                        RemoteItemContextMenu(item: item, onOpen: onOpen, onRename: onRename, onDelete: onDelete)
                    }
            }
            .width(min: 150, ideal: 240)

            TableColumn("Size", value: \.sortSize) { item in
                Text(item.isDirectory ? "—" : item.sizeDescription)
                    .foregroundStyle(.secondary)
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
            if comparator.keyPath == \RemoteFileItem.name {
                selectedSort = .name
            } else if comparator.keyPath == \RemoteFileItem.sortSize {
                selectedSort = .size
            } else {
                selectedSort = .modifiedDate
            }
            onSort(selectedSort, comparator.order == .forward)
        }
    }
}

private struct RemoteFileGrid: View {
    let items: [RemoteFileItem]
    @Binding var selection: Set<RemoteFileItem.ID>
    let onOpen: (RemoteFileItem) -> Void
    let onRename: (RemoteFileItem) -> Void
    let onDelete: (RemoteFileItem) -> Void

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
                        RemoteItemContextMenu(item: item, onOpen: onOpen, onRename: onRename, onDelete: onDelete)
                    }
                }
            }
            .padding(14)
        }
    }
}

private struct RemoteItemContextMenu: View {
    let item: RemoteFileItem
    let onOpen: (RemoteFileItem) -> Void
    let onRename: (RemoteFileItem) -> Void
    let onDelete: (RemoteFileItem) -> Void

    var body: some View {
        if item.isDirectory {
            Button("Open") { onOpen(item) }
        }
        Button("Rename") { onRename(item) }
        Button("Delete", role: .destructive) { onDelete(item) }
    }
}

private struct RemoteConnectionStatus: View {
    let state: ConnectionState

    var body: some View {
        switch state {
        case .disconnected:
            VStack(spacing: 10) {
                FileBridgeLogo(size: 64)
                Text("Not Connected").font(.headline)
                Text("Use New Connection to browse an SFTP server.")
                    .foregroundStyle(.secondary)
            }
        case .connecting, .awaitingHostTrust, .authenticating:
            ProgressView(state.statusDescription)
        case let .failed(message):
            ContentUnavailableView(
                "Connection Failed",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        case .connected:
            EmptyView()
        }
    }
}
