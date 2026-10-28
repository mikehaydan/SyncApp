//
//  SyncManagerTests.swift
//  SyncAppTests
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

@testable import SyncApp
import Testing
import Foundation

@MainActor
@Suite("SyncManager tests")
struct SyncManagerTests {

    // MARK: - Properties

    var sut: SyncManager!

    var store: OperationStoreSpy!
    var api: SyncAPISpy!

    // MARK: - Lifecycle

    init() {
        store = .init()
        api = .init()
        sut = SyncManager(store: store, api: api, reducer: FileReducer(), deviceID: "device-a")
    }

    // MARK: - Tests

    @Test("Testing record. Pending operation is saved with the current cursor")
    func recordSavesPendingOperation() async throws {
        // Given
        let fileID = UUID()
        store.cursor = 7

        // When
        try sut.record(.rename("New name"), fileID: fileID)

        // Then
        let saved = store.savedOperations.first?.first
        #expect(saved?.fileID == fileID)
        #expect(saved?.kind == .rename("New name"))
        #expect(saved?.deviceID == "device-a")
        #expect(saved?.baseCursor == 7)
        #expect(saved?.status == .pending)
        #expect(saved?.serverSeq == nil)
    }

    @Test("Testing record. Files are rebuilt and stored")
    func recordRefreshesFiles() async throws {
        // When
        try sut.record(.rename("New name"), fileID: UUID())

        // Then
        #expect(store.replaceFilesCallCount == 1)
    }

    @Test("Testing seed on empty store. Three files are created")
    func seedEmptyStore() async throws {
        // When
        try sut.seedIfNeeded()

        // Then
        #expect(store.saveCallCount == 3)
    }

    @Test("Testing seed on non-empty store. Nothing is created")
    func seedNonEmptyStore() async throws {
        // Given
        store.allOperationsToBeReturned = [.dummy()]

        // When
        try sut.seedIfNeeded()

        // Then
        #expect(store.saveCallCount == 0)
    }

    @Test("Testing sync success. Pending operation is pushed and marked synced with its server number")
    func syncPushesPendingOperations() async throws {
        // Given
        let pending = FileOperation.dummy(status: .pending)
        var stamped = try OperationDTO(pending)
        stamped.serverSeq = 3
        store.allOperationsToBeReturned = [pending]
        api.pushToBeReturned = [stamped]

        // When
        try await sut.sync()

        // Then
        var synced: [FileOperation] = []
        for batch in store.savedOperations {
            for operation in batch where operation.status == .synced {
                synced.append(operation)
            }
        }
        #expect(api.pushCallCount == 1)
        #expect(api.pushedOperations.first?.count == 1)
        #expect(synced.count == 1)
        #expect(synced.first?.id == pending.id)
        #expect(synced.first?.serverSeq == 3)
    }

    @Test("Testing sync with only synced operations. Nothing is pushed")
    func syncSkipsSyncedOperations() async throws {
        // Given
        store.allOperationsToBeReturned = [.dummy(serverSeq: 1, status: .synced)]

        // When
        try await sut.sync()

        // Then
        #expect(api.pushCallCount == 0)
        #expect(api.pullCallCount == 1)
    }

    @Test("Testing sync failure. Push error marks operations failed and skips pull")
    func syncPushFailure() async throws {
        // Given
        store.allOperationsToBeReturned = [.dummy(status: .pending)]
        api.pushErrorToBeReturned = TestError.failure

        // When
        let error = await #expect(throws: TestError.self) {
            try await sut.sync()
        }

        // Then
        #expect(error == .failure)
        #expect(store.savedOperations.last?.first?.status == .failed)
        #expect(api.pullCallCount == 0)
    }

    @Test("Testing sync pull. Remote operations are saved as synced and cursor moves")
    func syncPullSavesRemoteOperations() async throws {
        // Given
        let remote = FileOperation.dummy(deviceID: "device-b", serverSeq: 9)
        api.pullToBeReturned = PullResponse(operations: [try OperationDTO(remote)], cursor: 9)

        // When
        try await sut.sync()

        // Then
        var saved: [FileOperation] = []
        for batch in store.savedOperations {
            saved.append(contentsOf: batch)
        }
        #expect(saved.count == 1)
        #expect(saved.first?.id == remote.id)
        #expect(saved.first?.status == .synced)
        #expect(store.cursor == 9)
    }

    @Test("Testing sync pull with an undecodable operation. It is skipped and the rest is saved")
    func syncPullSkipsUndecodableOperation() async throws {
        // Given
        let remote = FileOperation.dummy(deviceID: "device-b", serverSeq: 9)
        let broken = OperationDTO(
            id: UUID(),
            fileID: UUID(),
            deviceID: "device-b",
            timestamp: Date(),
            baseCursor: 0,
            payload: Data("not json".utf8),
            serverSeq: 8
        )
        api.pullToBeReturned = PullResponse(operations: [broken, try OperationDTO(remote)], cursor: 9)

        // When
        try await sut.sync()

        // Then
        var saved: [FileOperation] = []
        for batch in store.savedOperations {
            saved.append(contentsOf: batch)
        }
        #expect(saved.count == 1)
        #expect(saved.first?.id == remote.id)
        #expect(store.cursor == 9)
    }

    @Test("Testing sync pull. Current cursor and device id are sent")
    func syncPullUsesCursorAndDeviceID() async throws {
        // Given
        store.cursor = 4

        // When
        try await sut.sync()

        // Then
        #expect(api.pulledCursors == [4])
        #expect(api.pulledDeviceIDs == ["device-a"])
    }

    @Test("Testing sync success. Files are rebuilt and stored")
    func syncRefreshesFiles() async throws {
        // When
        try await sut.sync()

        // Then
        #expect(store.replaceFilesCallCount == 1)
    }
}
