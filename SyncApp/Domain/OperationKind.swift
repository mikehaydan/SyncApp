//
//  OperationKind.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import Foundation

enum OperationKind: Codable, Equatable {
    case create(name: String, folderID: UUID)
    case rename(String)
    case move(folderID: UUID)
    case delete
    case addTag(Tag)
    case removeTag(tagID: UUID)
    case editTag(tagID: UUID, text: String)
}
