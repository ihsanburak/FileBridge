import AppKit
import SwiftUI

struct AboutFileBridgeView: View {
    @State private var isShowingAcknowledgements = false

    var body: some View {
        VStack(spacing: 16) {
            AboutBrandHeader()
            AboutConnectionMark()
            AboutVersionSection()
            AboutSupportSection()

            DisclosureGroup("Technical Information") {
                TechnicalInformationView()
                    .padding(.top, 8)
            }
            .font(.callout)

            HStack {
                Button("Copy Diagnostic Info") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(AppInfo.diagnosticInfo, forType: .string)
                }
                Spacer()
                Button("Acknowledgements") {
                    isShowingAcknowledgements = true
                }
            }
            .controlSize(.small)

            Text("© 2026 Captain21")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 390)
        .sheet(isPresented: $isShowingAcknowledgements) {
            AcknowledgementsView()
        }
    }
}

private struct AboutBrandHeader: View {
    var body: some View {
        VStack(spacing: 7) {
            FileBridgeLogo(size: 110)
            Text(AppInfo.name).font(.title.weight(.semibold))
            Text("Secure File Transfer")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Developed by \(AppInfo.studioName)")
                .font(.subheadline)
            Text("Built for simple and secure SFTP file management.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct AboutConnectionMark: View {
    var body: some View {
        HStack(spacing: 7) {
            Text("LOCAL").font(.caption2.monospaced().weight(.bold))
            ForEach(0..<5, id: \.self) { _ in
                Rectangle().fill(.secondary).frame(width: 4, height: 2)
            }
            Image(systemName: "lock.fill").font(.caption)
            ForEach(0..<5, id: \.self) { _ in
                Rectangle().fill(.secondary).frame(width: 4, height: 2)
            }
            Text("SERVER").font(.caption2.monospaced().weight(.bold))
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 2)
    }
}

private struct AboutVersionSection: View {
    var body: some View {
        Text(AppInfo.versionDescription)
            .font(.callout.monospaced())
            .foregroundStyle(.secondary)
    }
}

private struct AboutSupportSection: View {
    var body: some View {
        if let emailURL = URL(string: "mailto:\(AppInfo.supportEmail)") {
            Link(destination: emailURL) {
                Label(AppInfo.supportEmail, systemImage: "envelope")
            }
            .font(.callout)
        }
    }
}

private struct TechnicalInformationView: View {
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            TechnicalInformationRow(label: "Protocol", value: "SFTP over SSH")
            TechnicalInformationRow(label: "Architecture", value: AppInfo.architecture)
            TechnicalInformationRow(label: "macOS", value: AppInfo.macOSDescription)
            TechnicalInformationRow(label: "Version", value: AppInfo.version)
            TechnicalInformationRow(label: "Build", value: AppInfo.build)
        }
        .font(.caption)
        .textSelection(.enabled)
    }
}

private struct TechnicalInformationRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).lineLimit(1).truncationMode(.middle)
        }
    }
}

private struct AcknowledgementsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Acknowledgements").font(.title2.weight(.semibold))
            Text("FileBridge uses the following third-party software.")
                .foregroundStyle(.secondary)

            List {
                AcknowledgementRow(
                    name: "SSH2 0.2.0",
                    notice: "Copyright © 2022 Michael F. Collins, III. MIT License."
                )
                AcknowledgementRow(
                    name: "libssh2",
                    notice: "Copyright © 2000–2023 the libssh2 contributors. BSD 3-Clause License."
                )
                AcknowledgementRow(
                    name: "OpenSSL 0.2.0",
                    notice: "Copyright © 2022 Michael F. Collins, III. MIT License; OpenSSL is licensed under Apache License 2.0."
                )
            }
            .frame(height: 190)

            Text("The full license notices are retained in the resolved package sources distributed with this project.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}

private struct AcknowledgementRow: View {
    let name: String
    let notice: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name).font(.headline)
            Text(notice).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

struct FileBridgeSettingsView: View {
    var body: some View {
        TabView {
            SettingsPlaceholderView(
                title: "General",
                message: "General FileBridge preferences will appear here."
            )
            .tabItem { Label("General", systemImage: "gear") }

            SettingsPlaceholderView(
                title: "Transfers",
                message: "Transfer preferences will appear here."
            )
            .tabItem { Label("Transfers", systemImage: "arrow.left.arrow.right") }

            SettingsPlaceholderView(
                title: "Connections",
                message: "Connection preferences will appear here."
            )
            .tabItem { Label("Connections", systemImage: "network") }

            SettingsPlaceholderView(
                title: "Appearance",
                message: "Appearance preferences will appear here."
            )
            .tabItem { Label("Appearance", systemImage: "paintbrush") }

            SettingsPlaceholderView(
                title: "Security",
                message: "Security preferences will appear here."
            )
            .tabItem { Label("Security", systemImage: "lock") }
        }
        .scenePadding()
        .frame(width: 460, height: 250)
    }
}

private struct SettingsPlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: "gearshape", description: Text(message))
    }
}

struct FileBridgeCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About FileBridge") {
                openWindow(id: "about-filebridge")
            }
        }
    }
}
