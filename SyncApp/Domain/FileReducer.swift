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
        let ordered = operations.sorted(by: isOrderedBefore)
        guard let fileID = ordered.first?.fileID else { return nil }

        var name: String?
        var folderID: UUID?
        var tags: [Tag] = []
        var removedTagIDs: Set<UUID> = []
        var acceptedTagAdds: [FileOperation] = []
        var deletes: [FileOperation] = []

        for case let .create(createdName, createdFolderID) in ordered.map(\.kind) where name == nil {
            name = createdName
            folderID = createdFolderID
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
                guard tags.count < maxTags,
                      !removedTagIDs.contains(tag.id),
                      !tags.contains(where: { $0.id == tag.id }) else { continue }
                tags.append(tag)
                acceptedTagAdds.append(operation)
            case .removeTag(let tagID):
                tags.removeAll { $0.id == tagID }
                removedTagIDs.insert(tagID)
            case .editTag(let tagID, let text):
                if let index = tags.firstIndex(where: { $0.id == tagID }) {
                    tags[index].text = text
                }
            }
        }

        guard let name, let folderID else { return nil }
        guard !isDeleted(deletes: deletes, tagAdds: acceptedTagAdds) else { return nil }
        return FileItem(id: fileID, name: name, folderID: folderID, tags: tags)
    }

    private func isDeleted(deletes: [FileOperation], tagAdds: [FileOperation]) -> Bool {
        deletes.contains { delete in
            let deleteSeq = delete.serverSeq ?? .max
            return !tagAdds.contains { add in
                add.deviceID != delete.deviceID && add.baseCursor < deleteSeq
            }
        }
    }

    private func isOrderedBefore(_ lhs: FileOperation, _ rhs: FileOperation) -> Bool {
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        if lhs.deviceID != rhs.deviceID { return lhs.deviceID < rhs.deviceID }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
