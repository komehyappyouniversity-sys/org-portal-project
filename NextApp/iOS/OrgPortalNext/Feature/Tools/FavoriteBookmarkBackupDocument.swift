import SwiftUI
import UniformTypeIdentifiers

public struct FavoriteBookmarkBackupDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.json] }

    public var data: Data

    public init(data: Data = Data()) {
        self.data = data
    }

    public init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
