//
//  AdminSubscriptionManageView.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/15.
//

//
//  AdminSubscriptionManageView.swift
//  ictnagaoka-admin
//

import SwiftUI

struct AdminSubscriptionManageView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("動画サブスク管理")
                .font(.title2.bold())

            Text("この画面はこれから実装します。")
                .foregroundColor(.secondary)

            Text("会員ごとの動画視聴権限をここで管理します。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("動画サブスク管理")
        .navigationBarTitleDisplayMode(.inline)
    }
}
