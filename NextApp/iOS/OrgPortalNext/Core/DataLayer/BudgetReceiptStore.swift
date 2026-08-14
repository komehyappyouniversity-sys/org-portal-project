import Foundation

@MainActor
public protocol BudgetReceiptStore: AnyObject {
    func saveJPEGData(_ data: Data, reportId: UUID, entryId: UUID) throws -> String
    func loadData(reference: String) throws -> Data
    func delete(reference: String) throws
}

@MainActor
public final class LocalBudgetReceiptStore: BudgetReceiptStore {
    public static let maximumReceiptBytes = 10 * 1_024 * 1_024
    private let root: URL

    public init(fileManager: FileManager = .default) {
        root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BudgetReceipts", isDirectory: true)
    }

    public func saveJPEGData(_ data: Data, reportId: UUID, entryId: UUID) throws -> String {
        guard !data.isEmpty, data.count <= Self.maximumReceiptBytes else {
            throw BudgetReceiptStoreError.invalidSize
        }
        let directory = root.appendingPathComponent(reportId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent("\(entryId.uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url.path
    }

    public func loadData(reference: String) throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: reference))
    }

    public func delete(reference: String) throws {
        let url = URL(fileURLWithPath: reference)
        let rootPath = root.standardizedFileURL.path
        guard url.standardizedFileURL.path.hasPrefix(rootPath) else {
            throw BudgetReceiptStoreError.invalidReference
        }
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

public enum BudgetReceiptStoreError: Error, Equatable {
    case invalidSize
    case invalidReference
}
