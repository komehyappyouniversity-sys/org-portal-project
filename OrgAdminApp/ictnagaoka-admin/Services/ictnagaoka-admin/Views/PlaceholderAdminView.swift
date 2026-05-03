//
//  PlaceholderAdminView.swift
//  ictnagaoka-admin
//
//  Created by 根津浩 on 2026/04/16.
//

import SwiftUI

struct PlaceholderAdminView: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title2.bold())

            Text("この画面はこれから実装します")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
