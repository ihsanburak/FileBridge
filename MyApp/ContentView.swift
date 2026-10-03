import SwiftUI

struct ContentView: View {
    @State private var leftBrowser = FileBrowserState(
        initialURL: FileManager.default.homeDirectoryForCurrentUser
    )
    @State private var remoteBrowser = RemoteFileBrowserState()
    @State private var connectionManager = ConnectionManager()
    @State private var inspectorSelection: InspectorSelection?
    @State private var isInspectorVisible = false
    @State private var isConnectionSheetPresented = false
    @State private var editingProfile: SFTPConnectionProfile?
    @State private var savedProfileBeingEdited: SFTPConnectionProfile?
    @State private var profileToDelete: SFTPConnectionProfile?
    @State private var savedProfilePasswordPrompt: SFTPConnectionProfile?
    @State private var profileToRename: SFTPConnectionProfile?
    @State private var renamedProfileName = ""

    var body: some View {
        NavigationSplitView {
            SidebarView(
                savedProfiles: connectionManager.savedProfiles,
                onNavigate: { destination in leftBrowser.navigate(to: destination) },
                onConnect: connectSavedProfile,
                onEdit: editConnection,
                onRename: { profileToRename = $0; renamedProfileName = $0.name },
                onForgetPassword: connectionManager.forgetSavedPassword,
                onDelete: { profileToDelete = $0 }
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            BrowserWorkspace(
                leftBrowser: leftBrowser,
                remoteBrowser: remoteBrowser,
                connectionState: connectionManager.state,
                connectionProgress: connectionManager.connectionProgress,
                activeProfile: connectionManager.activeProfile,
                inspectorSelection: inspectorSelection,
                isInspectorVisible: isInspectorVisible,
                sftpService: connectionManager.service,
                onLocalSelectionChange: updateLocalInspector,
                onRemoteSelectionChange: updateRemoteInspector
            )
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    FileBridgeLogo(size: 34)
                        .help("FileBridge")
                }

                ToolbarItem {
                    Button {
                        editingProfile = nil
                        isConnectionSheetPresented = true
                    } label: {
                        Label("New Connection", systemImage: "plus.circle")
                    }
                    .help("New SFTP Connection")
                }

                ToolbarItem {
                    ConnectionStatusControl(
                        state: connectionManager.state,
                        onDisconnect: { Task { await connectionManager.disconnect() } }
                    )
                }

                ToolbarItem {
                    Button {
                        isInspectorVisible.toggle()
                    } label: {
                        Label(
                            isInspectorVisible ? "Hide Preview" : "Show Preview",
                            systemImage: "sidebar.right"
                        )
                    }
                    .help(isInspectorVisible ? "Hide Preview" : "Show Preview")
                }
            }
        }
        .frame(minWidth: 1_100, minHeight: 650)
        .sheet(isPresented: $isConnectionSheetPresented) {
            ConnectionSheet(
                initialProfile: editingProfile,
                onConnect: { profile, password, rememberPassword in
                    isConnectionSheetPresented = false
                    Task {
                        await connectionManager.connect(
                            profile: profile,
                            password: password,
                            rememberPassword: rememberPassword
                        )
                    }
                },
                onCancel: { isConnectionSheetPresented = false }
            )
        }
        .sheet(item: $savedProfileBeingEdited) { profile in
            SavedConnectionEditorSheet(
                profile: profile,
                onSave: { updatedProfile in
                    connectionManager.update(profile: updatedProfile)
                    savedProfileBeingEdited = nil
                },
                onCancel: { savedProfileBeingEdited = nil }
            )
        }
        .sheet(item: $savedProfilePasswordPrompt) { profile in
            SavedConnectionAuthenticationSheet(
                profile: profile,
                onConnect: { password, rememberPassword in
                    savedProfilePasswordPrompt = nil
                    Task { await connectionManager.connect(profile: profile, password: password, rememberPassword: rememberPassword) }
                },
                onCancel: { savedProfilePasswordPrompt = nil }
            )
        }
        .sheet(item: hostKeyBinding) { hostKey in
            HostKeyVerificationView(
                hostKey: hostKey,
                onCancel: {
                    Task { await connectionManager.cancelPendingConnection() }
                },
                onTrust: {
                    Task { await connectionManager.trustAndConnect(hostKey) }
                }
            )
        }
        .confirmationDialog(
            profileToDelete.map { "Delete \"\($0.name)\"?" } ?? "",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Profile and Keychain Password", role: .destructive) {
                if let profileToDelete {
                    connectionManager.delete(profile: profileToDelete, deleteCredential: true)
                }
                profileToDelete = nil
            }
            Button("Delete Profile Only", role: .destructive) {
                if let profileToDelete {
                    connectionManager.delete(profile: profileToDelete, deleteCredential: false)
                }
                profileToDelete = nil
            }
            Button("Cancel", role: .cancel) { profileToDelete = nil }
        } message: {
            Text("Passwords are stored separately in Keychain.")
        }
        .alert("Rename Connection", isPresented: Binding(
            get: { profileToRename != nil },
            set: { if !$0 { profileToRename = nil } }
        )) {
            TextField("Connection Name", text: $renamedProfileName)
            Button("Cancel", role: .cancel) { profileToRename = nil }
            Button("Rename") {
                if var profile = profileToRename {
                    profile.name = renamedProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !profile.name.isEmpty {
                        connectionManager.update(profile: profile)
                    }
                }
                profileToRename = nil
            }
        }
        .task(id: connectionManager.state) {
            if case .connected = connectionManager.state {
                await remoteBrowser.configure(
                    service: connectionManager.service,
                    homeDirectory: connectionManager.remoteHomeDirectory
                )
            } else {
                remoteBrowser.reset()
            }
        }
    }

    private var hostKeyBinding: Binding<HostKeyInfo?> {
        Binding(
            get: {
                if case let .awaitingHostTrust(hostKey) = connectionManager.state {
                    return hostKey
                }
                return nil
            },
            set: { _ in }
        )
    }

    private func presentConnection(_ profile: SFTPConnectionProfile) {
        editingProfile = profile
        isConnectionSheetPresented = true
    }

    private func editConnection(_ profile: SFTPConnectionProfile) {
        savedProfileBeingEdited = profile
    }

    private func connectSavedProfile(_ profile: SFTPConnectionProfile) {
        Task {
            if !(await connectionManager.connectSaved(profile)) {
                savedProfilePasswordPrompt = profile
            }
        }
    }

    private func updateLocalInspector(_ item: FileItem?) {
        inspectorSelection = item.map(InspectorSelection.local)
        isInspectorVisible = item != nil
    }

    private func updateRemoteInspector(_ item: RemoteFileItem?) {
        inspectorSelection = item.map(InspectorSelection.remote)
        isInspectorVisible = item != nil
    }
}

private struct BrowserWorkspace: View {
    @Bindable var leftBrowser: FileBrowserState
    @Bindable var remoteBrowser: RemoteFileBrowserState
    let connectionState: ConnectionState
    let connectionProgress: ConnectionProgress
    let activeProfile: SFTPConnectionProfile?
    let inspectorSelection: InspectorSelection?
    let isInspectorVisible: Bool
    let sftpService: SFTPService
    let onLocalSelectionChange: (FileItem?) -> Void
    let onRemoteSelectionChange: (RemoteFileItem?) -> Void

    private var profile: SFTPConnectionProfile? {
        if case let .connected(profile) = connectionState {
            return profile
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                FileBrowserPane(
                    browser: leftBrowser,
                    title: "Local Mac",
                    onSelectionChange: onLocalSelectionChange
                )
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)

                RemoteFileBrowserPane(
                    browser: remoteBrowser,
                    profile: profile,
                    connectionState: connectionState,
                    onSelectionChange: onRemoteSelectionChange
                )
                .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)

                if isInspectorVisible {
                    FileInspectorView(selection: inspectorSelection, sftpService: sftpService)
                        .frame(
                            minWidth: 280,
                            idealWidth: 300,
                            maxWidth: 340,
                            maxHeight: .infinity,
                            alignment: .top
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            ConnectionVisualizer(
                connectionState: connectionState,
                connectionProgress: connectionProgress,
                activeProfile: activeProfile,
                activity: remoteBrowser.visualizerActivity
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ConnectionStatusControl: View {
    let state: ConnectionState
    let onDisconnect: () -> Void

    var body: some View {
        if case let .connected(profile) = state {
            Menu {
                Text(profile.endpoint)
                Divider()
                Button("Disconnect", action: onDisconnect)
                    .help("Disconnect")
            } label: {
                Label(profile.name, systemImage: "circle.fill")
                    .foregroundStyle(.green)
            }
            .help("Disconnect")
        } else {
            Label(state.statusDescription, systemImage: "circle")
                .foregroundStyle(.secondary)
                .help("Connection Status")
        }
    }
}

#Preview {
    ContentView()
}
