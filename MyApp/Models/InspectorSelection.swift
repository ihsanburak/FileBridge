import Foundation

enum InspectorSelection: Identifiable, Equatable {
    case local(FileItem)
    case remote(RemoteFileItem)

    var id: String {
        switch self {
        case let .local(item):
            "local:" + item.url.absoluteString
        case let .remote(item):
            "remote:" + item.path
        }
    }

    var name: String {
        switch self {
        case let .local(item): item.name
        case let .remote(item): item.name
        }
    }

    var path: String {
        switch self {
        case let .local(item): item.url.path
        case let .remote(item): item.path
        }
    }

    var isDirectory: Bool {
        switch self {
        case let .local(item): item.isDirectory
        case let .remote(item): item.isDirectory
        }
    }

    var sizeDescription: String {
        switch self {
        case let .local(item): item.sizeDescription
        case let .remote(item): item.sizeDescription
        }
    }

    var modifiedDate: Date? {
        switch self {
        case let .local(item): item.modifiedDate
        case let .remote(item): item.modifiedDate
        }
    }

    var typeName: String {
        FilePresentation.typeName(name: name, isDirectory: isDirectory)
    }

    var iconName: String {
        FilePresentation.iconName(name: name, isDirectory: isDirectory)
    }

    var isImage: Bool {
        FilePresentation.isImage(name: name, isDirectory: isDirectory)
    }
}
