//
//  OperationStoreSpy.swift
//  SyncAppTests
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

@testable import SyncApp

final class OperationStoreSpy: OperationStore {
    var cursor = 0

    var allOperationsToBeReturned: [FileOperation] = []
    var allOperationsErrorToBeReturned: Error?
    var allOperationsCallCount = 0
    func allOperations() throws -> [FileOperation] {
        allOperationsCallCount += 1
        if let error = allOperationsErrorToBeReturned {
            throw error
        }
        return allOperationsToBeReturned
    }

    var saveErrorToBeReturned: Error?
    var saveCallCount = 0
    var savedOperations: [[FileOperation]] = []
    func save(_ operations: [FileOperation]) throws {
        saveCallCount += 1
        savedOperations.append(operations)
        if let error = saveErrorToBeReturned {
            throw error
        }
    }

    var allFilesToBeReturned: [FileItem] = []
    var allFilesErrorToBeReturned: Error?
    var allFilesCallCount = 0
    func allFiles() throws -> [FileItem] {
        allFilesCallCount += 1
        if let error = allFilesErrorToBeReturned {
            throw error
        }
        return allFilesToBeReturned
    }

    var replaceFilesErrorToBeReturned: Error?
    var replaceFilesCallCount = 0
    var replacedFiles: [[FileItem]] = []
    func replaceFiles(with files: [FileItem]) throws {
        replaceFilesCallCount += 1
        replacedFiles.append(files)
        if let error = replaceFilesErrorToBeReturned {
            throw error
        }
    }
}
