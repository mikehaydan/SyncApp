//
//  FileReducerTests.swift
//  SyncAppTests
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

@testable import SyncApp
import Testing
import Foundation

@MainActor
@Suite("FileReducer tests")
struct FileReducerTests {

    // MARK: - Properties

    var sut: FileReducer!

    let now = Date()
    let fileID = UUID()
    let folderID = UUID()

    // MARK: - Lifecycle

    init() {
        sut = FileReducer(maxTags: 2)
    }

    // MARK: - Tests

    @Test("Testing create. File appears with name and folder")
    func createFile() async throws {
        // Given
        let operations = [makeCreate()]

        // When
        let files = sut.reduce(operations)

        // Then
        #expect(files == [FileItem(id: fileID, name: "File", folderID: folderID, tags: [])])
    }

    @Test("Testing operations without create. No file")
    func noCreate() async throws {
        // Given
        let operations = [FileOperation.dummy(fileID: fileID, timestamp: now, kind: .rename("Orphan"))]

        // When
        let files = sut.reduce(operations)

        // Then
        #expect(files.isEmpty)
    }

    @Test("Testing rename. Later change wins regardless of input order")
    func renameLastChangeWins() async throws {
        // Given
        let early = FileOperation.dummy(fileID: fileID, deviceID: "device-a", timestamp: now.addingTimeInterval(1), kind: .rename("Early"))
        let late = FileOperation.dummy(fileID: fileID, deviceID: "device-b", timestamp: now.addingTimeInterval(2), kind: .rename("Late"))

        // When
        let files = sut.reduce([late, makeCreate(), early])

        // Then
        #expect(files.first?.name == "Late")
    }

    @Test("Testing rename. Equal timestamps are resolved by device id")
    func renameTieBreak() async throws {
        // Given
        let timestamp = now.addingTimeInterval(1)
        let fromA = FileOperation.dummy(fileID: fileID, deviceID: "device-a", timestamp: timestamp, kind: .rename("A"))
        let fromB = FileOperation.dummy(fileID: fileID, deviceID: "device-b", timestamp: timestamp, kind: .rename("B"))

        // When
        let first = sut.reduce([makeCreate(), fromA, fromB])
        let second = sut.reduce([fromB, fromA, makeCreate()])

        // Then
        #expect(first.first?.name == "B")
        #expect(second.first?.name == "B")
    }

    @Test("Testing rename with clock skew. Create is still applied first")
    func renameBeforeCreateTimestamp() async throws {
        // Given
        let create = FileOperation.dummy(fileID: fileID, timestamp: now.addingTimeInterval(10), kind: .create(name: "File", folderID: folderID))
        let rename = FileOperation.dummy(fileID: fileID, timestamp: now, kind: .rename("Renamed"))

        // When
        let files = sut.reduce([create, rename])

        // Then
        #expect(files.first?.name == "Renamed")
    }

    @Test("Testing move. Folder is updated")
    func move() async throws {
        // Given
        let newFolderID = UUID()
        let move = FileOperation.dummy(fileID: fileID, timestamp: now.addingTimeInterval(1), kind: .move(folderID: newFolderID))

        // When
        let files = sut.reduce([makeCreate(), move])

        // Then
        #expect(files.first?.folderID == newFolderID)
    }

    @Test("Testing add tag. SyncApp.Tag is added")
    func addTag() async throws {
        // Given
        let tag = SyncApp.Tag(id: UUID(), text: "work")

        // When
        let files = sut.reduce([makeCreate(), makeAddTag(tag, offset: 1)])

        // Then
        #expect(files.first?.tags == [tag])
    }

    @Test("Testing add tag. Same tag id is added once")
    func addTagDuplicate() async throws {
        // Given
        let tag = SyncApp.Tag(id: UUID(), text: "work")

        // When
        let files = sut.reduce([makeCreate(), makeAddTag(tag, offset: 1), makeAddTag(tag, offset: 2)])

        // Then
        #expect(files.first?.tags == [tag])
    }

    @Test("Testing add tag over the limit. Extra tag is ignored")
    func addTagOverLimit() async throws {
        // Given
        let first = SyncApp.Tag(id: UUID(), text: "1")
        let second = SyncApp.Tag(id: UUID(), text: "2")
        let third = SyncApp.Tag(id: UUID(), text: "3")

        // When
        let files = sut.reduce([
            makeCreate(),
            makeAddTag(third, offset: 3),
            makeAddTag(first, offset: 1),
            makeAddTag(second, offset: 2)
        ])

        // Then
        #expect(files.first?.tags == [first, second])
    }

    @Test("Testing remove tag. SyncApp.Tag is removed")
    func removeTag() async throws {
        // Given
        let tag = SyncApp.Tag(id: UUID(), text: "work")
        let remove = FileOperation.dummy(fileID: fileID, timestamp: now.addingTimeInterval(2), kind: .removeTag(tagID: tag.id))

        // When
        let files = sut.reduce([makeCreate(), makeAddTag(tag, offset: 1), remove])

        // Then
        #expect(files.first?.tags.isEmpty == true)
    }

    @Test("Testing remove tag. Removed tag does not come back when added again")
    func removedTagStaysRemoved() async throws {
        // Given
        let tag = SyncApp.Tag(id: UUID(), text: "work")
        let remove = FileOperation.dummy(fileID: fileID, timestamp: now.addingTimeInterval(2), kind: .removeTag(tagID: tag.id))

        // When
        let files = sut.reduce([makeCreate(), makeAddTag(tag, offset: 1), remove, makeAddTag(tag, offset: 3)])

        // Then
        #expect(files.first?.tags.isEmpty == true)
    }

    @Test("Testing edit tag. Text is changed")
    func editTag() async throws {
        // Given
        let tag = SyncApp.Tag(id: UUID(), text: "work")
        let edit = FileOperation.dummy(fileID: fileID, timestamp: now.addingTimeInterval(2), kind: .editTag(tagID: tag.id, text: "home"))

        // When
        let files = sut.reduce([makeCreate(), makeAddTag(tag, offset: 1), edit])

        // Then
        #expect(files.first?.tags.first?.text == "home")
    }

    @Test("Testing edit tag. Unknown tag is ignored")
    func editUnknownTag() async throws {
        // Given
        let edit = FileOperation.dummy(fileID: fileID, timestamp: now.addingTimeInterval(1), kind: .editTag(tagID: UUID(), text: "home"))

        // When
        let files = sut.reduce([makeCreate(), edit])

        // Then
        #expect(files.first?.tags.isEmpty == true)
    }

    @Test("Testing delete. File disappears")
    func delete() async throws {
        // Given
        let delete = makeDelete(deviceID: "device-a", serverSeq: 5)

        // When
        let files = sut.reduce([makeCreate(), delete])

        // Then
        #expect(files.isEmpty)
    }

    @Test("Testing delete and concurrent add tag from another device. File is kept with the tag")
    func deleteWithConcurrentAddTag() async throws {
        // Given
        let tag = SyncApp.Tag(id: UUID(), text: "remote")
        let delete = makeDelete(deviceID: "device-a", serverSeq: 5)
        let add = makeAddTag(tag, offset: 2, deviceID: "device-b", baseCursor: 2)

        // When
        let files = sut.reduce([makeCreate(), delete, add])

        // Then
        #expect(files == [FileItem(id: fileID, name: "File", folderID: folderID, tags: [tag])])
    }

    @Test("Testing delete and add tag made after seeing the delete. File stays deleted")
    func deleteWithLaterAddTag() async throws {
        // Given
        let tag = SyncApp.Tag(id: UUID(), text: "remote")
        let delete = makeDelete(deviceID: "device-a", serverSeq: 5)
        let add = makeAddTag(tag, offset: 2, deviceID: "device-b", baseCursor: 5)

        // When
        let files = sut.reduce([makeCreate(), delete, add])

        // Then
        #expect(files.isEmpty)
    }

    @Test("Testing delete and add tag from the same device. File stays deleted")
    func deleteWithSameDeviceAddTag() async throws {
        // Given
        let tag = SyncApp.Tag(id: UUID(), text: "mine")
        let add = makeAddTag(tag, offset: 1, deviceID: "device-a", baseCursor: 0)
        let delete = makeDelete(deviceID: "device-a", serverSeq: 5)

        // When
        let files = sut.reduce([makeCreate(), add, delete])

        // Then
        #expect(files.isEmpty)
    }

    @Test("Testing pending delete and add tag from another device. File is kept")
    func pendingDeleteWithRemoteAddTag() async throws {
        // Given
        let tag = SyncApp.Tag(id: UUID(), text: "remote")
        let delete = makeDelete(deviceID: "device-a", serverSeq: nil)
        let add = makeAddTag(tag, offset: 2, deviceID: "device-b", baseCursor: 100)

        // When
        let files = sut.reduce([makeCreate(), delete, add])

        // Then
        #expect(files.first?.tags == [tag])
    }

    @Test("Testing delete made after seeing the tag. File is deleted for good")
    func deleteAfterSeeingTag() async throws {
        // Given
        let tag = SyncApp.Tag(id: UUID(), text: "remote")
        let add = makeAddTag(tag, offset: 2, deviceID: "device-b", baseCursor: 1, serverSeq: 2)
        let secondDelete = makeDelete(deviceID: "device-a", serverSeq: 4, baseCursor: 3, offset: 3)

        // When
        let files = sut.reduce([makeCreate(), add, secondDelete])

        // Then
        #expect(files.isEmpty)
    }

    @Test("Testing several files. Each is built from its own operations")
    func severalFiles() async throws {
        // Given
        let otherFileID = UUID()
        let otherCreate = FileOperation.dummy(fileID: otherFileID, timestamp: now, kind: .create(name: "Other", folderID: folderID))
        let otherDelete = FileOperation.dummy(fileID: otherFileID, timestamp: now.addingTimeInterval(1), kind: .delete, serverSeq: 3)

        // When
        let files = sut.reduce([makeCreate(), otherCreate, otherDelete])

        // Then
        #expect(files.count == 1)
        #expect(files.first?.id == fileID)
    }

    @Test("Testing convergence. Same operations in any order give the same files")
    func convergence() async throws {
        // Given
        let tag = SyncApp.Tag(id: UUID(), text: "work")
        let operations = [
            makeCreate(),
            FileOperation.dummy(fileID: fileID, deviceID: "device-a", timestamp: now.addingTimeInterval(1), kind: .rename("A")),
            FileOperation.dummy(fileID: fileID, deviceID: "device-b", timestamp: now.addingTimeInterval(2), kind: .rename("B")),
            makeAddTag(tag, offset: 3),
            FileOperation.dummy(fileID: fileID, timestamp: now.addingTimeInterval(4), kind: .editTag(tagID: tag.id, text: "home"))
        ]

        // When
        let forward = sut.reduce(operations)
        let backward = sut.reduce(operations.reversed())

        // Then
        #expect(forward == backward)
    }

    // MARK: - Helpers

    private func makeCreate() -> FileOperation {
        FileOperation.dummy(fileID: fileID, timestamp: now, kind: .create(name: "File", folderID: folderID))
    }

    private func makeAddTag(
        _ tag: SyncApp.Tag,
        offset: TimeInterval,
        deviceID: String = "device-a",
        baseCursor: Int = 0,
        serverSeq: Int? = nil
    ) -> FileOperation {
        FileOperation.dummy(
            fileID: fileID,
            deviceID: deviceID,
            timestamp: now.addingTimeInterval(offset),
            baseCursor: baseCursor,
            kind: .addTag(tag),
            serverSeq: serverSeq
        )
    }

    private func makeDelete(deviceID: String, serverSeq: Int?, baseCursor: Int = 0, offset: TimeInterval = 1) -> FileOperation {
        FileOperation.dummy(
            fileID: fileID,
            deviceID: deviceID,
            timestamp: now.addingTimeInterval(offset),
            baseCursor: baseCursor,
            kind: .delete,
            serverSeq: serverSeq
        )
    }
}
