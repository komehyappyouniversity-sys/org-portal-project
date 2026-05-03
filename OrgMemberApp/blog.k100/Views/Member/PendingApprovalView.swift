//
//  PendingApprovalView.swift
//  blog.k100
//
//  Created by 根津浩 on 2026/04/15.
//

import SwiftUI

struct PendingApprovalView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("承認待ち")
                .font(.system(size: 28, weight: .bold))

            Text("管理者の承認をお待ちください。")
                .font(.body)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("会員ページ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
