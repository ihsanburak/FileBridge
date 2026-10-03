import AppKit
import SwiftUI

struct FileInspectorView: View {
    let selection: InspectorSelection?
    let sftpService: SFTPService?

    var body: some View {
        Group {
            if let selection {
                InspectorContent(selection: selection, sftpService: sftpService)
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Select a file or folder to inspect its details.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InspectorContent: View {
    let selection: InspectorSelection
    let sftpService: SFTPService?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                preview
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 7) {
                    Label(selection.name, systemImage: selection.iconName)
                        .font(.headline)
                        .lineLimit(2)

                    Text(selection.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    Divider()

                    InspectorMetadata(label: "Type", value: selection.typeName)
                    InspectorMetadata(label: "Size", value: selection.isDirectory ? "—" : selection.sizeDescription)

                    if let modifiedDate = selection.modifiedDate {
                        InspectorDateMetadata(date: modifiedDate)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var preview: some View {
        if !selection.isImage {
            Image(systemName: selection.iconName)
                .font(.system(size: 54))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch selection {
            case let .local(item):
                LocalImagePreview(url: item.url)
            case let .remote(item):
                if let sftpService {
                    RemoteImagePreview(item: item, service: sftpService)
                } else {
                    PreviewErrorView(message: "Connect to the server to load this image.")
                }
            }
        }
    }
}

private struct LocalImagePreview: View {
    let url: URL

    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else {
            PreviewErrorView(message: "This image could not be decoded by macOS.")
        }
    }
}

private struct RemoteImagePreview: View {
    let item: RemoteFileItem
    let service: SFTPService

    @State private var previewURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let previewURL, let image = NSImage(contentsOf: previewURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else if let errorMessage {
                PreviewErrorView(message: errorMessage)
            } else {
                ProgressView("Loading Preview…")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: item.path) {
            previewURL = nil
            errorMessage = nil
            do {
                previewURL = try await RemotePreviewCache.shared.previewURL(for: item, using: service)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .onDisappear {
            if let previewURL {
                Task { await RemotePreviewCache.shared.remove(previewURL) }
            }
        }
    }
}

private struct PreviewErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "Preview Unavailable",
            systemImage: "photo",
            description: Text(message)
        )
        .padding()
    }
}

private struct InspectorMetadata: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }
}

private struct InspectorDateMetadata: View {
    let date: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Modified").foregroundStyle(.secondary)
            Spacer()
            Text(date, format: .dateTime.year().month().day().hour().minute())
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }
}
