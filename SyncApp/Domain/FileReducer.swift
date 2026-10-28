//
//  FileReducer.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import Foundation

final class FileReducer {
    private let maxTags: Int

    init(maxTags: Int = 50) {
        self.maxTags = maxTags
    }

    func reduce(_ operations: [FileOperation]) -> [FileItem] {
        let operationsByFile = Dictionary(grouping: operations, by: { $0.fileID })
        var files: [FileItem] = []
        for fileOperations in operationsByFile.values {
            if let file = makeFile(from: fileOperations) {
                files.append(file)
            }
        }
        return files
    }

    private func makeFile(from operations: [FileOperation]) -> FileItem? {
        let ordered = operations.sorted { lhs, rhs in isOrderedBefore(lhs, rhs) }
        guard let firstOperation = ordered.first else { return nil }

        var name: String?
        var folderID: UUID?
        var tags: [Tag] = []
        var removedTagIDs: Set<UUID> = []
        var acceptedTagAdds: [FileOperation] = []
        var deletes: [FileOperation] = []

        for operation in ordered {
            if case .create(let createdName, let createdFolderID) = operation.kind {
                name = createdName
                folderID = createdFolderID
                break
            }
        }

        for operation in ordered {
            switch operation.kind {
            case .create:
                break
            case .rename(let newName):
                name = newName
            case .move(let newFolderID):
                folderID = newFolderID
            case .delete:
                deletes.append(operation)
            case .addTag(let tag):
                let isLimitReached = tags.count >= maxTags
                let wasRemoved = removedTagIDs.contains(tag.id)
                let alreadyExists = tags.contains(where: { existingTag in existingTag.id == tag.id })
                if isLimitReached || wasRemoved || alreadyExists {
                    continue
                }
                tags.append(tag)
                acceptedTagAdds.append(operation)
            case .removeTag(let tagID):
                tags.removeAll(where: { tag in tag.id == tagID })
                removedTagIDs.insert(tagID)
            case .editTag(let tagID, let text):
                if let index = tags.firstIndex(where: { tag in tag.id == tagID }) {
                    tags[index].text = text
                }
            }
        }

        guard let name = name, let folderID = folderID else { return nil }
        if isDeleted(deletes: deletes, tagAdds: acceptedTagAdds) { return nil }
        return FileItem(id: firstOperation.fileID, name: name, folderID: folderID, tags: tags)
    }

    private func isDeleted(deletes: [FileOperation], tagAdds: [FileOperation]) -> Bool {
        for delete in deletes {
            let deleteSeq = delete.serverSeq ?? Int.max
            var isRescued = false
            for add in tagAdds {
                if add.deviceID != delete.deviceID && add.baseCursor < deleteSeq {
                    isRescued = true
                    break
                }
            }
            if !isRescued { return true }
        }
        return false
    }

    private func isOrderedBefore(_ lhs: FileOperation, _ rhs: FileOperation) -> Bool {
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        if lhs.deviceID != rhs.deviceID { return lhs.deviceID < rhs.deviceID }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
