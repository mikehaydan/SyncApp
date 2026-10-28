//
//  SyncAPISpy.swift
//  SyncAppTests
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

@testable import SyncApp

final class SyncAPISpy: SyncAPI {

    var pushToBeReturned: [OperationDTO] = []
    var pushErrorToBeReturned: Error?
    var pushCallCount = 0
    var pushedOperations: [[OperationDTO]] = []
    func push(_ operations: [OperationDTO]) async throws -> [OperationDTO] {
        pushCallCount += 1
        pushedOperations.append(operations)
        if let error = pushErrorToBeReturned {
            throw error
        }
        return pushToBeReturned
    }

    var pullToBeReturned = PullResponse(operations: [], cursor: 0)
    var pullErrorToBeReturned: Error?
    var pullCallCount = 0
    var pulledCursors: [Int] = []
    var pulledDeviceIDs: [String] = []
    func pull(since cursor: Int, excluding deviceID: String) async throws -> PullResponse {
        pullCallCount += 1
        pulledCursors.append(cursor)
        pulledDeviceIDs.append(deviceID)
        if let error = pullErrorToBeReturned {
            throw error
        }
        return pullToBeReturned
    }
}
