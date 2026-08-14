import DesignSystem
import Foundation
import Model
import PhotosUI
import SwiftUI
import UIKit

public struct BudgetSettlementRootView: View {
    @ObservedObject private var model: BudgetSettlementFeatureModel
    @State private var showNewReport = false
    @State private var showMigration = false

    public init(model: BudgetSettlementFeatureModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            Group {
                if model.isLoading {
                    LoadingState()
                } else if let error = model.errorMessage {
                    ErrorState(message: error) { Task { await model.load() } }
                } else if model.reports.isEmpty {
                    EmptyState("帳簿はまだありません。", systemImage: "book.closed")
                } else {
                    List(model.reports) { report in
                        NavigationLink {
                            BudgetReportDetailView(model: model, reportId: report.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(report.bookName).font(.headline)
                                Text(report.fiscalYearStart, format: .dateTime.year().month().day())
                                    + Text(" ～ ")
                                    + Text(report.fiscalYearEnd, format: .dateTime.year().month().day())
                                Text("残高 \(money(report.balance))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("予算・決算")
            .toolbar {
                Button("帳簿を追加", systemImage: "plus") { showNewReport = true }
            }
            .sheet(isPresented: $showNewReport) {
                BudgetReportEditorView(model: model, editing: nil)
            }
            .task {
                await model.load()
                showMigration = model.migrationCandidateCount > 0
            }
            .onChange(of: model.migrationCandidateCount) { _, count in
                if count > 0 { showMigration = true }
            }
            .alert("端末内の帳簿を移行", isPresented: $showMigration) {
                Button("後で", role: .cancel) {}
                Button(model.isMigrating ? "移行中…" : "移行する") {
                    Task {
                        do { try await model.migrate() } catch { return }
                        showMigration = false
                    }
                }
                .disabled(model.isMigrating)
            } message: {
                Text("\(model.migrationCandidateCount)件の帳簿を、ログイン中の本人専用領域へ移行します。端末内データはバックアップとして残ります。")
            }
        }
    }
}

private struct BudgetReportDetailView: View {
    @ObservedObject var model: BudgetSettlementFeatureModel
    @Environment(\.dismiss) private var dismiss
    let reportId: UUID
    @State private var showEditor = false
    @State private var showDelete = false
    @State private var csvURL: URL?

    private var report: BudgetSettlementReport? {
        model.reports.first(where: { $0.id == reportId })
    }

    var body: some View {
        Group {
            if let report {
                List {
                    Section("会計年度") {
                        Text(report.fiscalYearStart, format: .dateTime.year().month().day())
                            + Text(" ～ ")
                            + Text(report.fiscalYearEnd, format: .dateTime.year().month().day())
                    }
                    Section("収支サマリー") {
                        LabeledContent("収入合計", value: money(report.incomeTotal))
                        LabeledContent("支出合計", value: money(report.expenseTotal))
                        LabeledContent("残高", value: money(report.balance))
                    }
                    NavigationLink("収支明細を見る") {
                        BudgetEntryListView(model: model, reportId: report.id)
                    }
                    Button("帳簿を削除", systemImage: "trash", role: .destructive) {
                        showDelete = true
                    }
                }
                .navigationTitle(report.bookName)
                .toolbar {
                    Button("CSV共有", systemImage: "square.and.arrow.up") {
                        csvURL = makeCSV(report: report)
                    }
                    Button("編集") { showEditor = true }
                }
                .sheet(isPresented: $showEditor) {
                    BudgetReportEditorView(model: model, editing: report)
                }
                .sheet(
                    isPresented: Binding(
                        get: { csvURL != nil },
                        set: { if !$0 { csvURL = nil } }
                    )
                ) {
                    if let csvURL { ActivityShareSheet(activityItems: [csvURL]) }
                }
                .alert("帳簿を削除しますか？", isPresented: $showDelete) {
                    Button("キャンセル", role: .cancel) {}
                    Button("削除", role: .destructive) {
                        Task {
                            do { try await model.delete(report) } catch { return }
                            dismiss()
                        }
                    }
                } message: {
                    Text("紐づく明細と領収書画像もすべて削除されます。この操作は取り消せません。")
                }
                .task { await model.loadEntries(reportId: report.id) }
            } else {
                EmptyState("帳簿が見つかりません。", systemImage: "book.closed")
            }
        }
    }

    private func makeCSV(report: BudgetSettlementReport) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(report.id.uuidString).csv")
        do {
            try BudgetSettlementCsvExporter.data(report: report, entries: model.entries)
                .write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

private struct BudgetEntryListView: View {
    @ObservedObject var model: BudgetSettlementFeatureModel
    let reportId: UUID
    @State private var editor: BudgetEntryEditorMode?
    @State private var deleting: BudgetEntry?

    private var report: BudgetSettlementReport? {
        model.reports.first(where: { $0.id == reportId })
    }

    var body: some View {
        Group {
            if model.isLoading {
                LoadingState()
            } else if let error = model.errorMessage {
                ErrorState(message: error) {
                    Task { await model.loadEntries(reportId: reportId) }
                }
            } else if model.entries.isEmpty {
                EmptyState("明細はまだありません。", systemImage: "list.bullet")
            } else {
                List(model.entries) { entry in
                    Button {
                        editor = .edit(entry)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.accountItem).font(.headline)
                                Text(entry.date, format: .dateTime.year().month().day())
                                if entry.receiptImageUrl != nil {
                                    Label("領収書画像あり", systemImage: "paperclip")
                                        .font(.caption)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(entry.entryType == .income ? "収入" : "支出")
                                    .font(.caption)
                                Text(money(entry.amount)).font(.headline)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("削除", role: .destructive) { deleting = entry }
                    }
                }
            }
        }
        .navigationTitle(report.map { "\($0.bookName)の明細" } ?? "収支明細")
        .toolbar {
            Button("明細を追加", systemImage: "plus") { editor = .new }
        }
        .sheet(item: $editor) { mode in
            if let report {
                BudgetEntryEditorView(model: model, report: report, mode: mode)
            }
        }
        .alert("明細を削除しますか？", isPresented: Binding(
            get: { deleting != nil },
            set: { if !$0 { deleting = nil } }
        )) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) {
                guard let deleting else { return }
                Task { await model.delete(deleting) }
            }
        } message: {
            Text("添付した領収書画像も削除されます。")
        }
        .task { await model.loadEntries(reportId: reportId) }
    }
}

private enum BudgetEntryEditorMode: Identifiable {
    case new
    case edit(BudgetEntry)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let entry): entry.id.uuidString
        }
    }
}

private struct BudgetEntryEditorView: View {
    @ObservedObject var model: BudgetSettlementFeatureModel
    @Environment(\.dismiss) private var dismiss
    let report: BudgetSettlementReport
    @State private var entry: BudgetEntry
    @State private var amountText: String
    @State private var receiptPickerItem: PhotosPickerItem?
    @State private var receiptData: Data?
    @State private var accountError: String?
    @State private var amountError: String?
    @State private var saveError: String?

    init(
        model: BudgetSettlementFeatureModel,
        report: BudgetSettlementReport,
        mode: BudgetEntryEditorMode
    ) {
        self.model = model
        self.report = report
        let value: BudgetEntry
        switch mode {
        case .new:
            value = BudgetEntry(
                reportId: report.id,
                date: .now,
                entryType: .expense,
                accountItem: "",
                amount: 0
            )
        case .edit(let existing):
            value = existing
        }
        _entry = State(initialValue: value)
        _amountText = State(initialValue: value.amount == 0
            ? "" : NSDecimalNumber(decimal: value.amount).stringValue)
    }

    var body: some View {
        let receiptTitle = receiptData != nil || entry.receiptImageUrl != nil
            ? "領収書画像を変更" : "領収書画像を添付"
        NavigationStack {
            Form {
                DatePicker("日付", selection: $entry.date, displayedComponents: .date)
                Picker("種別", selection: $entry.entryType) {
                    Text("収入").tag(BudgetEntryType.income)
                    Text("支出").tag(BudgetEntryType.expense)
                }
                TextField("科目（必須）", text: $entry.accountItem)
                if let accountError {
                    Text(accountError).foregroundStyle(.red).font(.caption)
                }
                TextField("詳細", text: $entry.detail, axis: .vertical)
                    .lineLimit(2...6)
                TextField("金額（必須）", text: $amountText)
                    .keyboardType(.decimalPad)
                if let amountError {
                    Text(amountError).foregroundStyle(.red).font(.caption)
                }
                TextField("証憑種別", text: $entry.receiptType)
                PhotosPicker(
                    selection: $receiptPickerItem,
                    matching: .images
                ) {
                    Label(
                        receiptTitle,
                        systemImage: "paperclip"
                    )
                }
                .onChange(of: receiptPickerItem) { _, item in
                    Task {
                        guard let source = try? await item?.loadTransferable(type: Data.self),
                              let image = UIImage(data: source) else {
                            receiptData = nil
                            return
                        }
                        receiptData = image.jpegData(compressionQuality: 0.9)
                    }
                }
                if let saveError {
                    Text(saveError).foregroundStyle(.red)
                }
            }
            .navigationTitle(entry.createdAt == entry.updatedAt ? "明細の登録" : "明細の編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                }
            }
        }
    }

    private func save() async {
        accountError = entry.accountItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "科目を入力してください。" : nil
        let amount = Decimal(string: amountText, locale: Locale(identifier: "en_US_POSIX"))
        amountError = switch amount {
        case nil: "金額を入力してください。"
        case let value? where value <= 0: "金額は0より大きい値を入力してください。"
        default: nil
        }
        guard accountError == nil, amountError == nil, let amount else { return }
        entry.amount = amount
        do {
            try await model.save(entry, receiptJPEG: receiptData)
            dismiss()
        } catch let validation as BudgetSettlementValidationError {
            saveError = validation.message
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct BudgetReportEditorView: View {
    @ObservedObject var model: BudgetSettlementFeatureModel
    @Environment(\.dismiss) private var dismiss
    @State private var report: BudgetSettlementReport
    @State private var nameError: String?
    @State private var dateError: String?
    @State private var saveError: String?

    init(model: BudgetSettlementFeatureModel, editing: BudgetSettlementReport?) {
        self.model = model
        if let editing {
            _report = State(initialValue: editing)
        } else {
            let calendar = Calendar.current
            let year = calendar.component(.year, from: .now)
            let start = calendar.date(from: DateComponents(year: year, month: 4, day: 1)) ?? .now
            let end = calendar.date(from: DateComponents(year: year + 1, month: 3, day: 31)) ?? .now
            _report = State(initialValue: BudgetSettlementReport(
                userId: "guest",
                fiscalYearStart: start,
                fiscalYearEnd: end,
                bookName: ""
            ))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("帳簿名（必須）", text: $report.bookName)
                if let nameError { Text(nameError).foregroundStyle(.red).font(.caption) }
                DatePicker("年度開始日", selection: $report.fiscalYearStart, displayedComponents: .date)
                DatePicker("年度終了日", selection: $report.fiscalYearEnd, displayedComponents: .date)
                if let dateError { Text(dateError).foregroundStyle(.red).font(.caption) }
                if let saveError { Text(saveError).foregroundStyle(.red) }
            }
            .navigationTitle(report.bookName.isEmpty ? "帳簿の登録" : "帳簿の編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                }
            }
        }
    }

    private func save() async {
        nameError = report.bookName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "帳簿名を入力してください。" : nil
        dateError = report.fiscalYearEnd < report.fiscalYearStart
            ? "終了日は開始日以降にしてください。" : nil
        guard nameError == nil, dateError == nil else { return }
        do {
            report.updatedAt = .now
            try await model.save(report)
            dismiss()
        } catch let validation as BudgetSettlementValidationError {
            saveError = validation.message
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private func money(_ value: Decimal) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "ja_JP")
    return formatter.string(from: NSDecimalNumber(decimal: value)) ?? value.description
}
