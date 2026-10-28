//
//  PullResponse.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

struct PullResponse: Codable {
    let operations: [OperationDTO]
    let cursor: Int
}
