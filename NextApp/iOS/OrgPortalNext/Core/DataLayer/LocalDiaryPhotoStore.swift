import Foundation

public struct LocalDiaryPhotoStore: DiaryPhotoStoring {
    private let rootDirectory: URL

    public init(rootDirectory: URL? = nil) {
        if let rootDirectory {
            self.rootDirectory = rootDirectory
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            self.rootDirectory = applicationSupport
                .appendingPathComponent("DiaryPhotos", isDirectory: true)
        }
    }

    public func saveJPEGData(_ data: Data, diaryId: UUID) throws -> String {
        guard !data.isEmpty, data.count <= 10 * 1_024 * 1_024 else {
            throw DiaryPhotoStoreError.invalidImageData
        }
        let directory = rootDirectory
            .appendingPathComponent(diaryId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let filename = "\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return "\(diaryId.uuidString)/\(filename)"
    }

    public func loadData(reference: String) throws -> Data {
        try Data(contentsOf: validatedURL(reference: reference))
    }

    public func delete(reference: String) throws {
        let url = try validatedURL(reference: reference)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func validatedURL(reference: String) throws -> URL {
        guard !reference.isEmpty, !reference.contains("..") else {
            throw DiaryPhotoStoreError.invalidReference
        }
        let candidate = rootDirectory.appendingPathComponent(reference).standardizedFileURL
        let rootPath = rootDirectory.standardizedFileURL.path + "/"
        guard candidate.path.hasPrefix(rootPath) else {
            throw DiaryPhotoStoreError.invalidReference
        }
        return candidate
    }
}

public enum DiaryPhotoStoreError: Error, Equatable {
    case invalidImageData
    case invalidReference
}
