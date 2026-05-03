//
//  AdminCategorySettingsView.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/15.
//

//
//  AdminCategorySettingsView.swift
//  ictnagaoka-admin
//

import SwiftUI

struct AdminCategorySettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("カテゴリ管理")
                .font(.title2.bold())

            Text("この画面はこれから実装します。")
                .foregroundColor(.secondary)

            Text("会員カテゴリの追加・編集・削除をここで管理します。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("カテゴリ管理")
        .navigationBarTitleDisplayMode(.inline)
    }
}
