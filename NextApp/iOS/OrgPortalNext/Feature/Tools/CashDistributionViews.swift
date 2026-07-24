import DesignSystem
import Model
import SwiftUI
import UniformTypeIdentifiers
import UIKit

public struct DenominationToolView: View {
    @ObservedObject private var model: CashDistributionFeatureModel

    public init(model: CashDistributionFeatureModel) {
        self.model = model
    }

    public var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    CashDistributionListView(model: model)
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("金種分配計算")
                            Text("配布する金額から必要な紙幣・硬貨の枚数を計算")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.2.fill")
                    }
                }
                NavigationLink {
                    DenominationCalculatorView()
                } label: {
                    Label {
                        VStack(alignment: .leading) {
                            Text("現金集計")
                            Text("手元の紙幣・硬貨の枚数から合計金額を計算")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "yensign.circle")
                    }
                }
            }
            .navigationTitle("金種計算")
        }
    }
}

private enum CashDistributionScreen: Identifiable {
    case add
    case edit(CashDistribution)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let value): value.id.uuidString
        }
    }
}

public struct CashDistributionListView: View {
    @ObservedObject private var model: CashDistributionFeatureModel
    @State private var editor: CashDistributionScreen?
    @State private var exportDocument: DiaryBackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var message: String?

    public init(model: CashDistributionFeatureModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            if model.isLoading {
                LoadingState()
            } else if let error = model.errorMessage {
                ErrorState(message: error) {
                    Task { await model.load() }
                }
            } else if model.distributions.isEmpty {
                EmptyState("右上の追加ボタンから最初の分配記録を登録できます。")
            } else {
                List(model.distributions) { distribution in
                    NavigationLink {
                        CashDistributionDetailView(
                            model: model,
                            distribution: distribution
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(distribution.title).font(.headline)
                            Text(distribution.distributionDate, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(
                                distribution.totalAmount,
                                format: .currency(code: "JPY")
                                    .precision(.fractionLength(0))
                            )
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
        .navigationTitle("金種分配計算")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("バックアップを書き出す", systemImage: "square.and.arrow.up") {
                        Task {
                            do {
                                exportDocument = DiaryBackupDocument(
                                    data: try await model.exportBackup()
                                )
                                isExporting = true
                            } catch {
                                message = "バックアップを書き出せませんでした。"
                            }
                        }
                    }
                    .disabled(model.distributions.isEmpty)
                    Button("バックアップを読み込む", systemImage: "square.and.arrow.down") {
                        isImporting = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                Button {
                    editor = .add
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("分配記録を追加")
            }
        }
        .task { await model.load() }
        .sheet(item: $editor) { value in
            CashDistributionEditorView(
                model: model,
                editing: {
                    if case .edit(let item) = value { return item }
                    return nil
                }()
            )
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "金種分配バックアップ"
        ) { result in
            message = result.isSuccess
                ? "バックアップを書き出しました。"
                : "バックアップを書き出せませんでした。"
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            Task {
                do {
                    let url = try result.get()
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
                    let count = try await model.importBackup(Data(contentsOf: url))
                    message = "\(count)件の分配記録を復元しました。"
                } catch {
                    message = "バックアップを読み込めませんでした。"
                }
            }
        }
        .alert(
            "金種分配計算",
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )
        ) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }
}

private struct CashDistributionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: CashDistributionFeatureModel
    @State private var value: CashDistribution
    @State private var errorMessage: String?

    init(
        model: CashDistributionFeatureModel,
        editing: CashDistribution?
    ) {
        self.model = model
        _value = State(initialValue: editing ?? CashDistribution())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("タイトル（必須）", text: $value.title)
                    DatePicker(
                        "配布日",
                        selection: $value.distributionDate,
                        displayedComponents: .date
                    )
                }
                ForEach($value.entries) { $entry in
                    Section("配布先") {
                        RecipientAmountFields(
                            number: 1,
                            name: $entry.recipientName1,
                            amount: $entry.amount1
                        )
                        RecipientAmountFields(
                            number: 2,
                            name: $entry.recipientName2,
                            amount: $entry.amount2
                        )
                        RecipientAmountFields(
                            number: 3,
                            name: $entry.recipientName3,
                            amount: $entry.amount3
                        )
                        TextField("受取確認者", text: $entry.receiverName)
                        Toggle(
                            "受取日を記録",
                            isOn: Binding(
                                get: { entry.receivedDate != nil },
                                set: { isEnabled in
                                    entry.receivedDate = isEnabled
                                        ? (entry.receivedDate ?? .now)
                                        : nil
                                }
                            )
                        )
                        if entry.receivedDate != nil {
                            DatePicker(
                                "受取日",
                                selection: Binding(
                                    get: { entry.receivedDate ?? .now },
                                    set: { entry.receivedDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                        }
                        Button("この行を削除", role: .destructive) {
                            value.entries.removeAll { $0.id == entry.id }
                            if value.entries.isEmpty {
                                value.entries = [CashDistributionEntry()]
                            }
                        }
                    }
                }
                Button("配布先の行を追加", systemImage: "plus") {
                    value.entries.append(CashDistributionEntry())
                }
            }
            .navigationTitle(value.title.isEmpty ? "分配記録を追加" : "分配記録を編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            do {
                                try await model.save(try value.validated())
                                dismiss()
                            } catch {
                                errorMessage = validationMessage(error)
                            }
                        }
                    }
                }
            }
            .alert(
                "入力内容を確認してください",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

private struct RecipientAmountFields: View {
    let number: Int
    @Binding var name: String
    @Binding var amount: Int64
    @State private var amountText: String

    init(
        number: Int,
        name: Binding<String>,
        amount: Binding<Int64>
    ) {
        self.number = number
        _name = name
        _amount = amount
        _amountText = State(initialValue: amount.wrappedValue == 0 ? "" : String(amount.wrappedValue))
    }

    var body: some View {
        HStack {
            TextField("受取人\(number)", text: $name)
            TextField("金額", text: $amountText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .onChange(of: amountText) { _, newValue in
                    let filtered = String(newValue.filter(\.isNumber).prefix(18))
                    if filtered != newValue { amountText = filtered }
                    amount = Int64(filtered) ?? 0
                }
            Text("円").foregroundStyle(.secondary)
        }
    }
}

private struct CashDistributionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: CashDistributionFeatureModel
    let distribution: CashDistribution
    @State private var isEditing = false
    @State private var isDeleting = false
    @State private var shareItems: [Any] = []
    @State private var isSharing = false

    var body: some View {
        List {
            Section("概要") {
                LabeledContent("配布日") {
                    Text(distribution.distributionDate, style: .date)
                }
                LabeledContent("合計") {
                    Text(
                        distribution.totalAmount,
                        format: .currency(code: "JPY").precision(.fractionLength(0))
                    )
                }
            }
            Section("必要な金種") {
                ForEach(Denomination.allCases.sorted(by: { $0.rawValue > $1.rawValue })) {
                    denomination in
                    let count = requiredCounts[denomination, default: 0]
                    if count > 0 {
                        LabeledContent("\(denomination.rawValue.formatted())円") {
                            Text("\(count)枚")
                        }
                    }
                }
            }
            ForEach(Array(distribution.entries.enumerated()), id: \.element.id) { index, entry in
                Section("配布先 \(index + 1)") {
                    ForEach(
                        Array(entry.recipientAmounts.enumerated()),
                        id: \.offset
                    ) { _, pair in
                        if pair.amount > 0 {
                            LabeledContent(pair.name) {
                                Text(
                                    pair.amount,
                                    format: .currency(code: "JPY")
                                        .precision(.fractionLength(0))
                                )
                            }
                        }
                    }
                    if !entry.receiverName.isEmpty {
                        LabeledContent("受取確認者", value: entry.receiverName)
                    }
                    if let receivedDate = entry.receivedDate {
                        LabeledContent("受取日") {
                            Text(receivedDate, style: .date)
                        }
                    }
                }
            }
        }
        .navigationTitle(distribution.title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("CSVを共有") { share(format: .csv) }
                    Button("PDFを共有") { share(format: .pdf) }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                Button("編集") { isEditing = true }
                Button("削除", role: .destructive) { isDeleting = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            CashDistributionEditorView(model: model, editing: distribution)
        }
        .sheet(isPresented: $isSharing) {
            ActivityShareSheet(activityItems: shareItems)
        }
        .alert("この分配記録を削除しますか？", isPresented: $isDeleting) {
            Button("削除", role: .destructive) {
                Task {
                    await model.delete(distribution)
                    dismiss()
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除した記録は元に戻せません。")
        }
    }

    private var requiredCounts: [Denomination: Int64] {
        (try? CashDistributionCalculator.requiredCounts(for: distribution.entries)) ?? [:]
    }

    private enum ShareFormat { case csv, pdf }

    private func share(format: ShareFormat) {
        do {
            let url: URL
            switch format {
            case .csv:
                url = try CashDistributionExporter.csvFile(distribution)
            case .pdf:
                url = try CashDistributionExporter.pdfFile(distribution)
            }
            shareItems = [url]
            isSharing = true
        } catch {
            shareItems = [distribution.title]
            isSharing = true
        }
    }
}

enum CashDistributionExporter {
    static func csvFile(_ distribution: CashDistribution) throws -> URL {
        try write(
            csvData(distribution),
            name: "\(safeFilename(distribution.title)).csv"
        )
    }

    static func csvData(_ distribution: CashDistribution) -> Data {
        var rows = [[
            "配布日",
            "タイトル",
            "受取人",
            "配布額",
            "受取日",
            "受取確認者"
        ]]
        let date = distribution.distributionDate.formatted(
            .dateTime.year().month().day()
        )
        for entry in distribution.entries {
            for pair in entry.recipientAmounts where pair.amount > 0 {
                rows.append([
                    date,
                    distribution.title,
                    pair.name,
                    String(pair.amount),
                    entry.receivedDate?.formatted(
                        .dateTime.year().month().day()
                    ) ?? "",
                    entry.receiverName
                ])
            }
        }
        let csv = rows.map { row in
            row.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
                .joined(separator: ",")
        }.joined(separator: "\r\n") + "\r\n"
        return Data([0xEF, 0xBB, 0xBF]) + Data(csv.utf8)
    }

    static func pdfFile(_ distribution: CashDistribution) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: 595, height: 842)
        )
        let data = renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 44
            func draw(_ text: String, font: UIFont = .systemFont(ofSize: 13)) {
                text.draw(
                    at: CGPoint(x: 44, y: y),
                    withAttributes: [.font: font]
                )
                y += font.lineHeight + 8
            }
            draw(distribution.title, font: .boldSystemFont(ofSize: 22))
            draw("配布日: \(distribution.distributionDate.formatted(date: .long, time: .omitted))")
            draw("合計: \(distribution.totalAmount.formatted())円", font: .boldSystemFont(ofSize: 16))
            draw("必要な金種", font: .boldSystemFont(ofSize: 16))
            let counts = (try? CashDistributionCalculator.requiredCounts(
                for: distribution.entries
            )) ?? [:]
            for denomination in Denomination.allCases.sorted(by: { $0.rawValue > $1.rawValue }) {
                let count = counts[denomination, default: 0]
                if count > 0 { draw("\(denomination.rawValue.formatted())円: \(count)枚") }
            }
            draw("配布先", font: .boldSystemFont(ofSize: 16))
            for entry in distribution.entries {
                for pair in entry.recipientAmounts where pair.amount > 0 {
                    if y > 790 {
                        context.beginPage()
                        y = 44
                    }
                    draw("\(pair.name): \(pair.amount.formatted())円")
                }
                if let receivedDate = entry.receivedDate {
                    draw(
                        "受取日: \(receivedDate.formatted(date: .long, time: .omitted))"
                    )
                }
                if !entry.receiverName.isEmpty {
                    draw("受取確認者: \(entry.receiverName)")
                }
            }
        }
        return try write(data, name: "\(safeFilename(distribution.title)).pdf")
    }

    private static func write(_ data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func safeFilename(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let result = value.components(separatedBy: invalid).joined(separator: "_")
        return result.isEmpty ? "金種分配" : result
    }
}

private func validationMessage(_ error: Error) -> String {
    switch error {
    case CashDistributionValidationError.titleRequired:
        "タイトルを入力してください。"
    case CashDistributionValidationError.amountRequired:
        "1件以上の配布額を入力してください。"
    case CashDistributionValidationError.recipientNameRequired:
        "配布額を入力した受取人の名前を入力してください。"
    case CashDistributionValidationError.negativeAmount:
        "配布額は0円以上で入力してください。"
    case CashDistributionValidationError.overflow:
        "金額が大きすぎます。"
    default:
        "保存できませんでした。"
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
