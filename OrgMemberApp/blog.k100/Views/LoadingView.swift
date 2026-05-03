//
//  LoadingView.swift
//  blog.k100
//
//  Created by 根津浩 on 2026/04/14.
//

import SwiftUI

struct LoadingView: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
