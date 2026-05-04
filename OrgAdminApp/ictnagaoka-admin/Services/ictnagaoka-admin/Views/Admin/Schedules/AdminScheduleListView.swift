//
//  AdminScheduleListView.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/15.
//

//
//  AdminScheduleListView.swift
//  ictnagaoka-admin
//

import SwiftUI
import Combine

struct AdminScheduleListView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("予定管理")
                .font(.title2.bold())

            Text("この画面はこれから実装します。")
                .foregroundColor(.secondary)

            Text("予定一覧・追加・編集をここで管理します。")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle("予定管理")
        .navigationBarTitleDisplayMode(.inline)
    }
}
