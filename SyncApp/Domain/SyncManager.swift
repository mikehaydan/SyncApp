//
//  SyncManager.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import Foundation

@MainActor
final class SyncManager {
    nonisolated static let rootFolderID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private var store: OperationStore
    private let api: SyncAPI
    private let reducer: FileReducer
    private let deviceID: String
    private var isSyncing = false
    private var needsAnotherPass = false

    init(store: OperationStore, api: SyncAPI, reducer: FileReducer, deviceID: String) {
        self.store = store
        self.api = api
        self.reducer = reducer
        self.deviceID = deviceID
    }

    func files() throws -> [FileItem] {
        try store.allFiles()
    }

    func operations() throws -> [FileOperation] {
        let operations = try store.allOperations()
        return operations.sorted { lhs, rhs in lhs.timestamp < rhs.timestamp }
    }

    func seedIfNeeded() throws {
        if !(try store.allOperations().isEmpty) { return }
        for name in ["Report.pdf", "Photo.jpg", "Notes.txt"] {
            try record(.create(name: name, folderID: SyncManager.rootFolderID), fileID: UUID())
        }
    }

    func record(_ kind: OperationKind, fileID: UUID) throws {
        let operation = FileOperation(
            id: UUID(),
            fileID: fileID,
            deviceID: deviceID,
            timestamp: Date(),
            baseCursor: store.cursor,
            kind: kind,
            serverSeq: nil,
            status: .pending
        )
        try store.save([operation])
        try refreshFiles()
    }

    func sync() async throws {
        if isSyncing {
            needsAnotherPass = true
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        repeat {
            needsAnotherPass = false
            try await push()
            try await pull()
            try refreshFiles()
        } while needsAnotherPass
    }

    private func refreshFiles() throws {
        let files = reducer.reduce(try store.allOperations())
        try store.replaceFiles(with: files)
    }

    private func push() async throws {
        var unsent: [FileOperation] = []
        for operation in try store.allOperations() {
            if operation.status != .synced {
                unsent.append(operation)
            }
        }
        if unsent.isEmpty { return }

        try setStatus(.syncing, for: &unsent)
        do {
            var dtos: [OperationDTO] = []
            for operation in unsent {
                dtos.append(try OperationDTO(operation))
            }
            let stamped = try await api.push(dtos)
            for index in unsent.indices {
                for dto in stamped {
                    if dto.id == unsent[index].id {
                        unsent[index].serverSeq = dto.serverSeq
                    }
                }
                unsent[index].status = .synced
            }
            try store.save(unsent)
        } catch {
            try setStatus(.failed, for: &unsent)
            throw error
        }
    }

    private func pull() async throws {
        let response = try await api.pull(since: store.cursor, excluding: deviceID)
        var remote: [FileOperation] = []
        for dto in response.operations {
            if let operation = try? FileOperation(dto, status: .synced) {
                remote.append(operation)
            }
        }
        try store.save(remote)
        store.cursor = response.cursor
    }

    private func setStatus(_ status: OperationStatus, for operations: inout [FileOperation]) throws {
        for index in operations.indices {
            operations[index].status = status
        }
        try store.save(operations)
    }
}
