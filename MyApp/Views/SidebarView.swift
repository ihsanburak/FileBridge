import SwiftUI

struct SidebarView: View {
    let savedProfiles: [SFTPConnectionProfile]
    let onNavigate: (URL) -> Void
    let onConnect: (SFTPConnectionProfile) -> Void
    let onEdit: (SFTPConnectionProfile) -> Void
    let onRename: (SFTPConnectionProfile) -> Void
    let onForgetPassword: (SFTPConnectionProfile) -> Void
    let onDelete: (SFTPConnectionProfile) -> Void

    private let fileManager = FileManager.default

    var body: some View {
        List {
            Section("Locations") {
                SidebarLocationRow(
                    title: "Choose Folder…",
                    systemImage: "folder.badge.plus",
                    action: { LocalFolderAuthorization.shared.chooseFolder(onNavigate: onNavigate) }
                )
                SidebarLocationRow(
                    title: "Local Mac",
                    systemImage: "desktopcomputer",
                    action: { onNavigate(fileManager.homeDirectoryForCurrentUser) }
                )
                SidebarLocationRow(
                    title: "Documents",
                    systemImage: "doc",
                    action: { onNavigate(url(for: .documentDirectory)) }
                )
                SidebarLocationRow(
                    title: "Downloads",
                    systemImage: "arrow.down.circle",
                    action: { onNavigate(url(for: .downloadsDirectory)) }
                )
            }

            Section("Saved SFTP Connections") {
                if savedProfiles.isEmpty {
                    SidebarStatusRow(title: "No saved connections", systemImage: "lock")
                } else {
                    ForEach(savedProfiles) { profile in
                        Button {
                            onConnect(profile)
                        } label: {
                            Label(profile.name, systemImage: "desktopcomputer")
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Connect") { onConnect(profile) }
                            Button("Edit Connection…") { onEdit(profile) }
                            Button("Rename…") { onRename(profile) }
                            Button("Forget Saved Password") { onForgetPassword(profile) }
                            Divider()
                            Button("Delete", role: .destructive) { onDelete(profile) }
                        }
                    }
                }
            }

            Section("Favorites") {
                SidebarLocationRow(
                    title: "Desktop",
                    systemImage: "rectangle.grid.1x2",
                    action: { onNavigate(url(for: .desktopDirectory)) }
                )
                SidebarLocationRow(
                    title: "Home",
                    systemImage: "house",
                    action: { onNavigate(fileManager.homeDirectoryForCurrentUser) }
                )
            }

            Section("Connected Servers") {
                SidebarStatusRow(title: "None connected", systemImage: "network")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Locations")
    }

    private func url(for directory: FileManager.SearchPathDirectory) -> URL {
        fileManager.urls(for: directory, in: .userDomainMask).first ?? fileManager.homeDirectoryForCurrentUser
    }
}

private struct SidebarLocationRow: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .buttonStyle(.plain)
    }
}

private struct SidebarStatusRow: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
