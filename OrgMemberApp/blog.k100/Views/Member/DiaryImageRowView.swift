//
//  DiaryImageRowView.swift
//  blog.k100
//
//  Created by 根津浩 on 2026/04/14.
//

import SwiftUI

struct DiaryImageRowView: View {
    let imageUrls: [String]

    var body: some View {
        if !imageUrls.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(imageUrls, id: \.self) { url in
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .empty:
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(.systemGray5))
                                    ProgressView()
                                }

                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()

                            case .failure:
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(.systemGray5))
                                    Image(systemName: "photo")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                }

                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 112, height: 112)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
