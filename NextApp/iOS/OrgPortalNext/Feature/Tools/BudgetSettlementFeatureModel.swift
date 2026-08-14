import DataLayer
import Foundation
import Model
import Session

@MainActor
public final class BudgetSettlementFeatureModel: ObservableObject {
    @Published public private(set) var reports: [BudgetSettlementReport] = []
    @Published public private(set) var entries: [BudgetEntry] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var isMigrating = false
    @Published public private(set) var migrationCandidateCount = 0
    @Published public private(set) var migrationResult: BudgetMigrationResult?
    @Published public private(set) var errorMessage: String?

    private let localRepository: BudgetSettlementRepository
    private let localReceiptStore: BudgetReceiptStore
    private let remoteRepository: BudgetSettlementRemoteRepository
    private let migrationService: BudgetSettlementMigrationService
    private let session: AppSession

    public init(
        localRepository: BudgetSettlementRepository,
        localReceiptStore: BudgetReceiptStore,
        remoteRepository: BudgetSettlementRemoteRepository,
        migrationService: BudgetSettlementMigrationService,
        session: AppSession
    ) {
        self.localRepository = localRepository
        self.localReceiptStore = localReceiptStore
        self.remoteRepository = remoteRepository
        self.migrationService = migrationService
        self.session = session
    }

    public func load() async {
        isLoading = true
        errorMessage = nil
        do {
            if let auth {
                reports = try await remoteRepository.fetchReports(auth: auth)
                migrationCandidateCount = try await migrationService.candidateCount(auth: auth)
            } else {
                reports = try await localRepository.fetchReports()
                migrationCandidateCount = 0
            }
            isLoading = false
        } catch {
            show(error)
        }
    }

    public func loadEntries(reportId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            if let auth {
                entries = try await remoteRepository.fetchEntries(auth: auth, reportId: reportId)
            } else {
                entries = try await localRepository.fetchEntries(reportId: reportId)
            }
            isLoading = false
        } catch {
            show(error)
        }
    }

    public func save(_ report: BudgetSettlementReport) async throws {
        if let auth {
            var value = report
            value.userId = auth.userId
            try await remoteRepository.saveReport(auth: auth, report: value)
        } else {
            try await localRepository.saveReport(report)
        }
        await load()
    }

    public func save(_ entry: BudgetEntry, receiptJPEG: Data?) async throws {
        var value = entry
        if let receiptJPEG {
            if let auth {
                value.receiptImageUrl = try await remoteRepository.uploadReceipt(
                    auth: auth,
                    reportId: entry.reportId,
                    entryId: entry.id,
                    jpegData: receiptJPEG
                )
            } else {
                value.receiptImageUrl = try localReceiptStore.saveJPEGData(
                    receiptJPEG,
                    reportId: entry.reportId,
                    entryId: entry.id
                )
            }
        }
        value.updatedAt = .now
        if let auth {
            try await remoteRepository.saveEntry(auth: auth, entry: value)
        } else {
            try await localRepository.saveEntry(value)
        }
        await loadEntries(reportId: entry.reportId)
        await load()
    }

    public func delete(_ entry: BudgetEntry) async {
        do {
            if let auth {
                try await remoteRepository.deleteEntry(
                    auth: auth,
                    reportId: entry.reportId,
                    entryId: entry.id
                )
            } else {
                try await localRepository.deleteEntry(id: entry.id)
            }
            await loadEntries(reportId: entry.reportId)
            await load()
        } catch {
            show(error)
        }
    }

    public func delete(_ report: BudgetSettlementReport) async throws {
        if let auth {
            try await remoteRepository.deleteReport(auth: auth, reportId: report.id)
        } else {
            try await localRepository.deleteReport(id: report.id)
        }
        entries = []
        await load()
    }

    public func migrate() async throws {
        guard let auth else { throw BudgetSettlementFeatureError.authenticationRequired }
        isMigrating = true
        defer { isMigrating = false }
        do {
            migrationResult = try await migrationService.migrate(auth: auth)
            migrationCandidateCount = 0
            await load()
        } catch {
            show(error)
            throw error
        }
    }

    private var auth: BudgetRemoteAuth? {
        guard let userId = session.authenticatedUserId,
              let token = session.authenticationToken else { return nil }
        return BudgetRemoteAuth(userId: userId, idToken: token)
    }

    private func show(_ error: Error) {
        isLoading = false
        isMigrating = false
        errorMessage = error.localizedDescription
    }
}

public enum BudgetSettlementFeatureError: Error, Equatable {
    case authenticationRequired
}
