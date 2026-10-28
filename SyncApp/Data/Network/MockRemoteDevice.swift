//
//  MockRemoteDevice.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import Foundation

final class MockRemoteDevice {
    enum Change {
        case rename
        case addTag
        case delete
    }

    private let server: InMemorySyncServer
    private let deviceID = "remote-device"

    init(server: InMemorySyncServer) {
        self.server = server
    }

    func createFile() async throws {
        let kind = OperationKind.create(name: "Remote file", folderID: SyncManager.rootFolderID)
        try await push(kind, fileID: UUID())
    }

    func apply(_ change: Change, to fileID: UUID) async throws {
        var kind: OperationKind
        switch change {
        case .rename:
            kind = .rename("Renamed remotely")
        case .addTag:
            kind = .addTag(Tag(id: UUID(), text: "remote"))
        case .delete:
            kind = .delete
        }
        try await push(kind, fileID: fileID)
    }

    private func push(_ kind: OperationKind, fileID: UUID) async throws {
        let operation = FileOperation(
            id: UUID(),
            fileID: fileID,
            deviceID: deviceID,
            timestamp: Date(),
            baseCursor: 0,
            kind: kind,
            serverSeq: nil,
            status: .pending
        )
        _ = try await server.push([try OperationDTO(operation)])
    }
}
