//
//  FileItem.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import Foundation

struct FileItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    var folderID: UUID
    var tags: [Tag]
}
