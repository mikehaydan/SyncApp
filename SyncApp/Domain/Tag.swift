//
//  Tag.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import Foundation

struct Tag: Codable, Hashable, Identifiable {
    let id: UUID
    var text: String
}
