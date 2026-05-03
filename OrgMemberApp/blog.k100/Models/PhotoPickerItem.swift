//
//  PhotoPickerItem.swift
//  blog.k100
//
//  Created by 根津浩 on 2026/04/14.
//

import Foundation

struct PhotoPickerItem: Identifiable, Hashable {
    let id: UUID
    let data: Data

    init(id: UUID = UUID(), data: Data) {
        self.id = id
        self.data = data
    }
}
