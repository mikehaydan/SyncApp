//
//  OperationStore.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import Foundation

protocol OperationStore: AnyObject {
    var cursor: Int { get set }

    func allOperations() throws -> [FileOperation]
    func save(_ operations: [FileOperation]) throws

    func allFiles() throws -> [FileItem]
    func replaceFiles(with files: [FileItem]) throws
}
