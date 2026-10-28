//
//  FilesViewModel.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import Foundation
import Observation

@Observable
@MainActor
final class FilesViewModel {
    static let maxTags = 50

    private let manager: SyncManager
    private let remote: MockRemoteDevice

    private(set) var files: [FileItem] = []
    private(set) var operations: [FileOperation] = []
    private(set) var errorMessage: String?

    var isOnline = true {
        didSet {
            if isOnline {
                startSync()
            }
        }
    }

    var pendingCount: Int {
        var count = 0
        for operation in operations {
            if operation.status != .synced {
                count += 1
            }
        }
        return count
    }

    init(manager: SyncManager, remote: MockRemoteDevice) {
        self.manager = manager
        self.remote = remote
    }

    func start() {
        perform {
            try manager.seedIfNeeded()
        }
        startSync()
    }

    func createFile(named name: String) {
        record(.create(name: name, folderID: SyncManager.rootFolderID), fileID: UUID())
    }

    func rename(_ file: FileItem, to name: String) {
        record(.rename(name), fileID: file.id)
    }

    func delete(_ file: FileItem) {
        record(.delete, fileID: file.id)
    }

    func addTag(to file: FileItem, text: String) {
        if file.tags.count >= FilesViewModel.maxTags {
            errorMessage = "A file can have at most \(FilesViewModel.maxTags) tags"
            return
        }
        record(.addTag(Tag(id: UUID(), text: text)), fileID: file.id)
    }

    func editTag(_ tag: Tag, in file: FileItem, text: String) {
        record(.editTag(tagID: tag.id, text: text), fileID: file.id)
    }

    func removeTag(_ tag: Tag, from file: FileItem) {
        record(.removeTag(tagID: tag.id), fileID: file.id)
    }

    func simulateRemoteCreate() {
        simulateRemote { remote in
            try await remote.createFile()
        }
    }

    func simulateRemote(_ change: MockRemoteDevice.Change) {
        guard let file = files.first else { return }
        simulateRemote { remote in
            try await remote.apply(change, to: file.id)
        }
    }

    private func simulateRemote(_ work: @escaping (MockRemoteDevice) async throws -> Void) {
        Task {
            do {
                try await work(remote)
            } catch {
                errorMessage = error.localizedDescription
            }
            if isOnline {
                startSync()
            }
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    private func record(_ kind: OperationKind, fileID: UUID) {
        perform {
            try manager.record(kind, fileID: fileID)
        }
        if isOnline {
            startSync()
        }
    }

    private func startSync() {
        Task {
            do {
                try await manager.sync()
            } catch {
                errorMessage = error.localizedDescription
            }
            reload()
        }
    }

    private func perform(_ work: () throws -> Void) {
        do {
            try work()
        } catch {
            errorMessage = error.localizedDescription
        }
        reload()
    }

    private func reload() {
        do {
            let loaded = try manager.files()
            files = loaded.sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            operations = try manager.operations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
