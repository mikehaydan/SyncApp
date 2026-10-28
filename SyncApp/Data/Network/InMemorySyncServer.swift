//
//  InMemorySyncServer.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import Foundation

actor InMemorySyncServer: SyncAPI {
    private var log: [OperationDTO] = []

    func push(_ operations: [OperationDTO]) async throws -> [OperationDTO] {
        var stamped: [OperationDTO] = []
        for var operation in operations {
            var existing: OperationDTO?
            for entry in log {
                if entry.id == operation.id {
                    existing = entry
                }
            }
            if let existing = existing {
                stamped.append(existing)
                continue
            }
            operation.serverSeq = log.count + 1
            log.append(operation)
            stamped.append(operation)
        }
        return stamped
    }

    func pull(since cursor: Int, excluding deviceID: String) async throws -> PullResponse {
        var fresh: [OperationDTO] = []
        for entry in log {
            if let seq = entry.serverSeq, seq > cursor, entry.deviceID != deviceID {
                fresh.append(entry)
            }
        }
        return PullResponse(operations: fresh, cursor: log.count)
    }
}
