import Foundation
import Model

public struct BudgetRemoteAuth: Equatable, Sendable {
    public let userId: String
    public let idToken: String

    public init(userId: String, idToken: String) {
        self.userId = userId
        self.idToken = idToken
    }
}

@MainActor
public protocol BudgetSettlementRemoteRepository: AnyObject {
    func fetchReports(auth: BudgetRemoteAuth) async throws -> [BudgetSettlementReport]
    func fetchEntries(auth: BudgetRemoteAuth, reportId: UUID) async throws -> [BudgetEntry]
    func saveReport(auth: BudgetRemoteAuth, report: BudgetSettlementReport) async throws
    func saveEntry(auth: BudgetRemoteAuth, entry: BudgetEntry) async throws
    func deleteEntry(auth: BudgetRemoteAuth, reportId: UUID, entryId: UUID) async throws
    func deleteReport(auth: BudgetRemoteAuth, reportId: UUID) async throws
    func uploadReceipt(
        auth: BudgetRemoteAuth,
        reportId: UUID,
        entryId: UUID,
        jpegData: Data
    ) async throws -> String
}

@MainActor
public final class FirebaseRESTBudgetSettlementRepository: BudgetSettlementRemoteRepository {
    private let projectId: String
    private let storageBucket: String
    private let session: URLSession

    public init(
        projectId: String,
        storageBucket: String,
        session: URLSession = .shared
    ) {
        self.projectId = projectId
        self.storageBucket = storageBucket
        self.session = session
    }

    public func fetchReports(auth: BudgetRemoteAuth) async throws -> [BudgetSettlementReport] {
        try await fetchDocuments(
            path: reportsPath(userId: auth.userId),
            token: auth.idToken
        ).compactMap(Self.report)
    }

    public func fetchEntries(
        auth: BudgetRemoteAuth,
        reportId: UUID
    ) async throws -> [BudgetEntry] {
        return try await fetchDocuments(
            path: entriesPath(userId: auth.userId, reportId: reportId),
            token: auth.idToken
        )
            .compactMap { Self.entry($0, reportId: reportId) }
            .sorted {
                if $0.date != $1.date { return $0.date > $1.date }
                return $0.updatedAt > $1.updatedAt
            }
    }

    public func saveReport(
        auth: BudgetRemoteAuth,
        report: BudgetSettlementReport
    ) async throws {
        guard report.userId == auth.userId else {
            throw FirebaseBudgetSettlementError.ownerMismatch
        }
        let entries = try await fetchEntries(auth: auth, reportId: report.id)
        let value = try report.validated(now: report.updatedAt)
            .recalculated(entries: entries, now: report.updatedAt)
        _ = try await requestJSON(
            method: "PATCH",
            path: "\(reportsPath(userId: auth.userId))/\(value.id.uuidString)",
            token: auth.idToken,
            body: Self.document(report: value)
        )
    }

    public func saveEntry(auth: BudgetRemoteAuth, entry: BudgetEntry) async throws {
        let value = try entry.validated(now: entry.updatedAt)
        _ = try await requestJSON(
            method: "PATCH",
            path: "\(entriesPath(userId: auth.userId, reportId: entry.reportId))/\(entry.id.uuidString)",
            token: auth.idToken,
            body: Self.document(entry: value)
        )
        guard let report = try await fetchReports(auth: auth).first(where: { $0.id == entry.reportId }) else {
            throw FirebaseBudgetSettlementError.reportNotFound
        }
        try await saveReport(auth: auth, report: report)
    }

    public func deleteEntry(
        auth: BudgetRemoteAuth,
        reportId: UUID,
        entryId: UUID
    ) async throws {
        _ = try await requestJSON(
            method: "DELETE",
            path: "\(entriesPath(userId: auth.userId, reportId: reportId))/\(entryId.uuidString)",
            token: auth.idToken
        )
        try await deleteStorageObject(auth: auth, reportId: reportId, entryId: entryId)
        if let report = try await fetchReports(auth: auth).first(where: { $0.id == reportId }) {
            try await saveReport(auth: auth, report: report)
        }
    }

    public func deleteReport(auth: BudgetRemoteAuth, reportId: UUID) async throws {
        let entries = try await fetchEntries(auth: auth, reportId: reportId)
        for entry in entries {
            _ = try await requestJSON(
                method: "DELETE",
                path: "\(entriesPath(userId: auth.userId, reportId: reportId))/\(entry.id.uuidString)",
                token: auth.idToken
            )
            try await deleteStorageObject(auth: auth, reportId: reportId, entryId: entry.id)
        }
        _ = try await requestJSON(
            method: "DELETE",
            path: "\(reportsPath(userId: auth.userId))/\(reportId.uuidString)",
            token: auth.idToken
        )
    }

    public func uploadReceipt(
        auth: BudgetRemoteAuth,
        reportId: UUID,
        entryId: UUID,
        jpegData: Data
    ) async throws -> String {
        guard !jpegData.isEmpty else { throw BudgetReceiptStoreError.invalidSize }
        let objectPath = storageObjectPath(
            userId: auth.userId,
            reportId: reportId,
            entryId: entryId
        )
        var components = URLComponents(
            string: "https://firebasestorage.googleapis.com/v0/b/\(storageBucket)/o"
        )!
        components.queryItems = [
            URLQueryItem(name: "uploadType", value: "media"),
            URLQueryItem(name: "name", value: objectPath)
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(auth.idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = jpegData
        _ = try await perform(request)
        return "gs://\(storageBucket)/\(objectPath)"
    }

    private func deleteStorageObject(
        auth: BudgetRemoteAuth,
        reportId: UUID,
        entryId: UUID
    ) async throws {
        let objectPath = storageObjectPath(
            userId: auth.userId,
            reportId: reportId,
            entryId: entryId
        )
        let encoded = objectPath.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        var request = URLRequest(
            url: URL(
                string: "https://firebasestorage.googleapis.com/v0/b/\(storageBucket)/o/\(encoded)"
            )!
        )
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(auth.idToken)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 404 || (200...299).contains(http.statusCode) else {
            throw FirebaseBudgetSettlementError.requestFailed
        }
    }

    private func requestJSON(
        method: String,
        path: String,
        token: String,
        body: [String: Any]? = nil
    ) async throws -> [String: Any] {
        let root = "https://firestore.googleapis.com/v1/projects/\(projectId)" +
            "/databases/(default)/documents/\(path)"
        var request = URLRequest(url: URL(string: root)!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, method == "GET", http.statusCode == 404 {
            return [:]
        }
        try Self.requireSuccess(response)
        guard !data.isEmpty else { return [:] }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    private func fetchDocuments(
        path: String,
        token: String
    ) async throws -> [[String: Any]] {
        var documents: [[String: Any]] = []
        var pageToken: String?
        repeat {
            var components = URLComponents()
            components.queryItems = [URLQueryItem(name: "pageSize", value: "100")]
            if let pageToken {
                components.queryItems?.append(URLQueryItem(name: "pageToken", value: pageToken))
            }
            let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
            let page = try await requestJSON(
                method: "GET",
                path: path + query,
                token: token
            )
            documents += page["documents"] as? [[String: Any]] ?? []
            pageToken = (page["nextPageToken"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        } while pageToken != nil
        return documents
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        try Self.requireSuccess(response)
        return data
    }

    private static func requireSuccess(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw FirebaseBudgetSettlementError.requestFailed
        }
    }

    private func reportsPath(userId: String) -> String {
        "memberPrivate/\(userId)/budgetSettlementReports"
    }

    private func entriesPath(userId: String, reportId: UUID) -> String {
        "\(reportsPath(userId: userId))/\(reportId.uuidString)/entries"
    }

    private func storageObjectPath(userId: String, reportId: UUID, entryId: UUID) -> String {
        "memberPrivate/\(userId)/budgetSettlementReports/\(reportId.uuidString)/\(entryId.uuidString).jpg"
    }

    private static func document(report: BudgetSettlementReport) -> [String: Any] {
        ["fields": [
            "userId": ["stringValue": report.userId],
            "fiscalYearStart": ["stringValue": dateOnly(report.fiscalYearStart)],
            "fiscalYearEnd": ["stringValue": dateOnly(report.fiscalYearEnd)],
            "bookName": ["stringValue": report.bookName],
            "incomeTotal": ["doubleValue": NSDecimalNumber(decimal: report.incomeTotal).doubleValue],
            "expenseTotal": ["doubleValue": NSDecimalNumber(decimal: report.expenseTotal).doubleValue],
            "balance": ["doubleValue": NSDecimalNumber(decimal: report.balance).doubleValue],
            "createdAt": ["timestampValue": timestamp(report.createdAt)],
            "updatedAt": ["timestampValue": timestamp(report.updatedAt)]
        ]]
    }

    private static func document(entry: BudgetEntry) -> [String: Any] {
        ["fields": [
            "reportId": ["stringValue": entry.reportId.uuidString],
            "date": ["stringValue": dateOnly(entry.date)],
            "entryType": ["stringValue": entry.entryType.rawValue],
            "accountItem": ["stringValue": entry.accountItem],
            "detail": ["stringValue": entry.detail],
            "amount": ["doubleValue": NSDecimalNumber(decimal: entry.amount).doubleValue],
            "receiptType": ["stringValue": entry.receiptType],
            "receiptImageUrl": ["stringValue": entry.receiptImageUrl ?? ""],
            "createdAt": ["timestampValue": timestamp(entry.createdAt)],
            "updatedAt": ["timestampValue": timestamp(entry.updatedAt)]
        ]]
    }

    private static func report(_ document: [String: Any]) -> BudgetSettlementReport? {
        guard let fields = document["fields"] as? [String: Any],
              let id = documentId(document),
              let userId = value("userId", fields),
              let start = parseDateOnly(value("fiscalYearStart", fields)),
              let end = parseDateOnly(value("fiscalYearEnd", fields)),
              let bookName = value("bookName", fields),
              let createdAt = parseTimestamp(value("createdAt", fields)),
              let updatedAt = parseTimestamp(value("updatedAt", fields)) else { return nil }
        return BudgetSettlementReport(
            id: id,
            userId: userId,
            fiscalYearStart: start,
            fiscalYearEnd: end,
            bookName: bookName,
            incomeTotal: decimal(value("incomeTotal", fields)),
            expenseTotal: decimal(value("expenseTotal", fields)),
            balance: decimal(value("balance", fields)),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func entry(_ document: [String: Any], reportId: UUID) -> BudgetEntry? {
        guard let fields = document["fields"] as? [String: Any],
              let id = documentId(document),
              let date = parseDateOnly(value("date", fields)),
              let typeRaw = value("entryType", fields),
              let type = BudgetEntryType(rawValue: typeRaw),
              let accountItem = value("accountItem", fields),
              let createdAt = parseTimestamp(value("createdAt", fields)),
              let updatedAt = parseTimestamp(value("updatedAt", fields)) else { return nil }
        let receipt = value("receiptImageUrl", fields)
        return BudgetEntry(
            id: id,
            reportId: reportId,
            date: date,
            entryType: type,
            accountItem: accountItem,
            detail: value("detail", fields) ?? "",
            amount: decimal(value("amount", fields)),
            receiptType: value("receiptType", fields) ?? "",
            receiptImageUrl: receipt?.isEmpty == false ? receipt : nil,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private static func documentId(_ document: [String: Any]) -> UUID? {
        guard let name = document["name"] as? String else { return nil }
        return UUID(uuidString: String(name.split(separator: "/").last ?? ""))
    }

    private static func value(_ key: String, _ fields: [String: Any]) -> String? {
        guard let field = fields[key] as? [String: Any] else { return nil }
        return (field["stringValue"] ?? field["timestampValue"] ??
            field["doubleValue"] ?? field["integerValue"]).map(String.init(describing:))
    }

    private static func decimal(_ value: String?) -> Decimal {
        Decimal(string: value ?? "0", locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private static func dateOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func parseDateOnly(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    private static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func parseTimestamp(_ value: String?) -> Date? {
        guard let value else { return nil }
        return ISO8601DateFormatter().date(from: value)
    }
}

@MainActor
public final class BudgetSettlementMigrationService {
    private let localRepository: BudgetSettlementRepository
    private let localReceiptStore: BudgetReceiptStore
    private let remoteRepository: BudgetSettlementRemoteRepository
    private let stateStore: BudgetMigrationStateStore

    public init(
        localRepository: BudgetSettlementRepository,
        localReceiptStore: BudgetReceiptStore,
        remoteRepository: BudgetSettlementRemoteRepository,
        stateStore: BudgetMigrationStateStore
    ) {
        self.localRepository = localRepository
        self.localReceiptStore = localReceiptStore
        self.remoteRepository = remoteRepository
        self.stateStore = stateStore
    }

    public func candidateCount(auth: BudgetRemoteAuth) async throws -> Int {
        if stateStore.isCompleted(userId: auth.userId) { return 0 }
        return try await localRepository.fetchReports().count
    }

    public func migrate(auth: BudgetRemoteAuth) async throws -> BudgetMigrationResult {
        let reports = try await localRepository.fetchReports()
        var entryCount = 0
        for report in reports {
            let entries = try await localRepository.fetchEntries(reportId: report.id)
            try await remoteRepository.saveReport(
                auth: auth,
                report: BudgetSettlementReport(
                    id: report.id,
                    userId: auth.userId,
                    fiscalYearStart: report.fiscalYearStart,
                    fiscalYearEnd: report.fiscalYearEnd,
                    bookName: report.bookName,
                    incomeTotal: report.incomeTotal,
                    expenseTotal: report.expenseTotal,
                    balance: report.balance,
                    createdAt: report.createdAt,
                    updatedAt: report.updatedAt
                )
            )
            for entry in entries {
                var value = entry
                if let reference = entry.receiptImageUrl {
                    value.receiptImageUrl = try await remoteRepository.uploadReceipt(
                        auth: auth,
                        reportId: report.id,
                        entryId: entry.id,
                        jpegData: try localReceiptStore.loadData(reference: reference)
                    )
                }
                try await remoteRepository.saveEntry(auth: auth, entry: value)
                entryCount += 1
            }
        }
        let remoteIds = Set(try await remoteRepository.fetchReports(auth: auth).map(\.id))
        guard reports.allSatisfy({ remoteIds.contains($0.id) }) else {
            throw FirebaseBudgetSettlementError.migrationVerificationFailed
        }
        stateStore.markCompleted(userId: auth.userId)
        return BudgetMigrationResult(reportCount: reports.count, entryCount: entryCount)
    }
}

@MainActor
public protocol BudgetMigrationStateStore: AnyObject {
    func isCompleted(userId: String) -> Bool
    func markCompleted(userId: String)
}

@MainActor
public final class UserDefaultsBudgetMigrationStateStore: BudgetMigrationStateStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func isCompleted(userId: String) -> Bool {
        defaults.bool(forKey: key(userId))
    }

    public func markCompleted(userId: String) {
        defaults.set(true, forKey: key(userId))
    }

    private func key(_ userId: String) -> String {
        "budgetSettlementMigration.completed.\(userId)"
    }
}

public struct BudgetMigrationResult: Equatable, Sendable {
    public let reportCount: Int
    public let entryCount: Int

    public init(reportCount: Int, entryCount: Int) {
        self.reportCount = reportCount
        self.entryCount = entryCount
    }
}

public enum FirebaseBudgetSettlementError: Error, Equatable {
    case ownerMismatch
    case reportNotFound
    case requestFailed
    case migrationVerificationFailed
}
