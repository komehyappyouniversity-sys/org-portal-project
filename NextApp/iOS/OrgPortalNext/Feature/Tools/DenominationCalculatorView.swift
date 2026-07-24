import DesignSystem
import Model
import SwiftUI

public struct DenominationCalculatorView: View {
    @State private var countTexts = Dictionary(
        uniqueKeysWithValues: Denomination.allCases.map { ($0, "") }
    )
    @FocusState private var focusedDenomination: Denomination?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.contentSpacing) {
                    totalCard
                    denominationSection(
                        title: "denomination.coins",
                        denominations: Denomination.allCases.filter(\.isCoin)
                    )
                    denominationSection(
                        title: "denomination.banknotes",
                        denominations: Denomination.allCases.filter { !$0.isCoin }
                    )
                    Button("action.clear", role: .destructive) {
                        clear()
                    }
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.minimumTapHeight)
                    .buttonStyle(.bordered)
                    .disabled(countTexts.values.allSatisfy(\.isEmpty))
                }
                .padding()
            }
            .navigationTitle("screen.denomination")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("action.done") {
                        focusedDenomination = nil
                    }
                }
            }
        }
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("denomination.total")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let total {
                Text(
                    total,
                    format: .currency(code: "JPY")
                        .precision(.fractionLength(0))
                )
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(DesignTokens.brandGreen)
                .contentTransition(.numericText())
                .accessibilityLabel(
                    Text("合計金額 \(total.formatted())円")
                )
            } else {
                Text("denomination.input_too_large")
                    .font(.headline)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(DesignTokens.brandGreen.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadius))
    }

    private func denominationSection(
        title: LocalizedStringKey,
        denominations: [Denomination]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(denominations) { denomination in
                denominationRow(denomination)
                if denomination != denominations.last {
                    Divider()
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private func denominationRow(_ denomination: Denomination) -> some View {
        HStack(spacing: 12) {
            Text("\(denomination.rawValue.formatted())円")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                changeCount(for: denomination, delta: -1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignTokens.brandGreen)
            .disabled(currentCount(for: denomination) == 0)
            .accessibilityLabel(
                Text("\(denomination.rawValue)円を1枚減らす")
            )

            TextField(
                "0",
                text: countBinding(for: denomination)
            )
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .textFieldStyle(.roundedBorder)
            .frame(width: 92)
            .focused($focusedDenomination, equals: denomination)
            .accessibilityLabel(
                Text("\(denomination.rawValue)円の枚数")
            )

            Text("denomination.unit")
                .foregroundStyle(.secondary)

            Button {
                changeCount(for: denomination, delta: 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignTokens.brandGreen)
            .accessibilityLabel(
                Text("\(denomination.rawValue)円を1枚増やす")
            )
        }
        .frame(minHeight: DesignTokens.minimumTapHeight)
    }

    private var parsedCounts: [Denomination: Int64]? {
        var result: [Denomination: Int64] = [:]
        for denomination in Denomination.allCases {
            let text = countTexts[denomination, default: ""]
            guard text.isEmpty || Int64(text) != nil else {
                return nil
            }
            result[denomination] = Int64(text) ?? 0
        }
        return result
    }

    private var total: Int64? {
        guard let parsedCounts else { return nil }
        return try? DenominationCalculator.total(counts: parsedCounts)
    }

    private func countBinding(for denomination: Denomination) -> Binding<String> {
        Binding {
            countTexts[denomination, default: ""]
        } set: { newValue in
            countTexts[denomination] = String(
                newValue.filter { ("0"..."9").contains($0) }.prefix(18)
            )
        }
    }

    private func currentCount(for denomination: Denomination) -> Int64 {
        Int64(countTexts[denomination, default: ""]) ?? 0
    }

    private func changeCount(for denomination: Denomination, delta: Int64) {
        let current = currentCount(for: denomination)
        let (updated, overflow) = current.addingReportingOverflow(delta)
        guard !overflow else { return }
        let normalized = max(0, updated)
        countTexts[denomination] = normalized == 0 ? "" : String(normalized)
    }

    private func clear() {
        focusedDenomination = nil
        for denomination in Denomination.allCases {
            countTexts[denomination] = ""
        }
    }
}
