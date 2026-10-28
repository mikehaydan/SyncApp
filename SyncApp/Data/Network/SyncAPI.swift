//
//  SyncAPI.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import Foundation

protocol SyncAPI: AnyObject {
    func push(_ operations: [OperationDTO]) async throws -> [OperationDTO]
    func pull(since cursor: Int, excluding deviceID: String) async throws -> PullResponse
}
