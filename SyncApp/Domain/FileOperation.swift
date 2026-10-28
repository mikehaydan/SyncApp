//
//  FileOperation.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import Foundation

struct FileOperation: Identifiable, Equatable {
    let id: UUID
    let fileID: UUID
    let deviceID: String
    let timestamp: Date
    let baseCursor: Int
    let kind: OperationKind
    var serverSeq: Int?
    var status: OperationStatus
}
