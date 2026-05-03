//
//  AdminRequestsDetailView.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/16.
//

import SwiftUI

struct AdminRequestsDetailView: View {
    let request: AdminRequestItem
    @ObservedObject var store: AdminRequestsStore

    @Environment(\.dismiss) private var dismiss

    @State private var isProcessing = false
    @State private var showApproveAlert = false
    @State private var showErrorAlert = false
    @State private var errorText = ""
    @State private var rejectReason = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                infoCard
                actionCard
            }
            .padding()
        }
        .navigationTitle("申請詳細")
        .navigationBarTitleDisplayMode(.inline)
        .alert("承認しますか？", isPresented: $showApproveAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("承認") {
                Task { await approve() }
            }
        } message: {
            Text("この申請を承認して会員登録します。")
        }
        .alert("エラー", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorText)
        }
    }

    private var safeOrganizationId: String {
        request.organizationId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("申請内容")
                .font(.headline)

            row("お名前", request.name)
            row("ふりがな", request.furigana)
            row("会員番号", request.memberId)
            row("電話番号", request.phone)
            row("メール", request.email)
            row("住所", request.address)
            row("備考", request.note)
            row("UID", request.uid)
            row("状態", statusLabel(request.status))

            if let createdAt = request.createdAt {
                row("申請日時", formatted(createdAt))
            }

            if let updatedAt = request.updatedAt {
                row("更新日時", formatted(updatedAt))
            }

            row("organizationId", request.organizationId)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("対応")
                .font(.headline)

            Button {
                showApproveAlert = true
            } label: {
                HStack {
                    Spacer()
                    if isProcessing {
                        ProgressView()
                    } else {
                        Text("承認する")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .frame(height: 50)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(isProcessing)

            VStack(alignment: .leading, spacing: 8) {
                Text("差し戻し理由")
                    .font(.subheadline.bold())

                TextEditor(text: $rejectReason)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                    )
                    .cornerRadius(10)
            }

            Button {
                Task { await reject() }
            } label: {
                HStack {
                    Spacer()
                    if isProcessing {
                        ProgressView()
                    } else {
                        Text("差し戻し")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .frame(height: 50)
                .background(Color.red)
                .cornerRadius(12)
            }
            .disabled(isProcessing)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : value)
                .font(.body)
        }
    }

    private func approve() async {
        guard !safeOrganizationId.isEmpty else {
            errorText = "organizationId が取得できません。"
            showErrorAlert = true
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await store.approve(request: request)
            dismiss()
        } catch {
            errorText = "承認に失敗しました: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func reject() async {
        guard !safeOrganizationId.isEmpty else {
            errorText = "organizationId が取得できません。"
            showErrorAlert = true
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            try await store.reject(request: request, reason: rejectReason)
            dismiss()
        } catch {
            errorText = "差し戻しに失敗しました: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "pending":
            return "承認待ち"
        case "approved":
            return "承認済み"
        case "rejected":
            return "差し戻し"
        default:
            return status
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
}
