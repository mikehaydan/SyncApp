//
//  OperationDTO.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import Foundation

struct OperationDTO: Codable, Equatable {
    let id: UUID
    let fileID: UUID
    let deviceID: String
    let timestamp: Date
    let baseCursor: Int
    let payload: Data
    var serverSeq: Int?
}

extension OperationDTO {
    init(_ operation: FileOperation) throws {
        self.init(
            id: operation.id,
            fileID: operation.fileID,
            deviceID: operation.deviceID,
            timestamp: operation.timestamp,
            baseCursor: operation.baseCursor,
            payload: try JSONEncoder().encode(operation.kind),
            serverSeq: operation.serverSeq
        )
    }
}

extension FileOperation {
    init(_ dto: OperationDTO, status: OperationStatus) throws {
        self.init(
            id: dto.id,
            fileID: dto.fileID,
            deviceID: dto.deviceID,
            timestamp: dto.timestamp,
            baseCursor: dto.baseCursor,
            kind: try JSONDecoder().decode(OperationKind.self, from: dto.payload),
            serverSeq: dto.serverSeq,
            status: status
        )
    }
}
