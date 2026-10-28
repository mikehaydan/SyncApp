//
//  CoreDataOperationStore.swift
//  SyncApp
//
//  Created by Mykhailo Haidan on 28/10/2026.
//

import CoreData

final class CoreDataOperationStore: OperationStore {
    private let context: NSManagedObjectContext
    private let defaults: UserDefaults
    private let cursorKey = "sync.cursor"

    init(context: NSManagedObjectContext, defaults: UserDefaults = .standard) {
        self.context = context
        self.defaults = defaults
    }

    var cursor: Int {
        get { defaults.integer(forKey: cursorKey) }
        set { defaults.set(newValue, forKey: cursorKey) }
    }

    func allOperations() throws -> [FileOperation] {
        let request = NSFetchRequest<CDOperation>(entityName: "CDOperation")
        let objects = try context.fetch(request)
        var operations: [FileOperation] = []
        for object in objects {
            if let operation = makeOperation(from: object) {
                operations.append(operation)
            }
        }
        return operations
    }

    func save(_ operations: [FileOperation]) throws {
        for operation in operations {
            let object = try findOperation(id: operation.id) ?? CDOperation(context: context)
            try fill(object, from: operation)
        }
        try context.save()
    }

    func allFiles() throws -> [FileItem] {
        let request = NSFetchRequest<CDFile>(entityName: "CDFile")
        let objects = try context.fetch(request)
        var files: [FileItem] = []
        for object in objects {
            let tags = try JSONDecoder().decode([Tag].self, from: object.tags)
            files.append(FileItem(id: object.id, name: object.name, folderID: object.folderID, tags: tags))
        }
        return files
    }

    func replaceFiles(with files: [FileItem]) throws {
        let request = NSFetchRequest<CDFile>(entityName: "CDFile")
        for object in try context.fetch(request) {
            context.delete(object)
        }
        for file in files {
            let object = CDFile(context: context)
            object.id = file.id
            object.name = file.name
            object.folderID = file.folderID
            object.tags = try JSONEncoder().encode(file.tags)
        }
        try context.save()
    }

    private func findOperation(id: UUID) throws -> CDOperation? {
        let request = NSFetchRequest<CDOperation>(entityName: "CDOperation")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fill(_ object: CDOperation, from operation: FileOperation) throws {
        object.id = operation.id
        object.fileID = operation.fileID
        object.deviceID = operation.deviceID
        object.timestamp = operation.timestamp
        object.baseCursor = Int64(operation.baseCursor)
        object.serverSeq = Int64(operation.serverSeq ?? 0)
        object.status = operation.status.rawValue
        object.payload = try JSONEncoder().encode(operation.kind)
    }

    private func makeOperation(from object: CDOperation) -> FileOperation? {
        guard let kind = try? JSONDecoder().decode(OperationKind.self, from: object.payload) else { return nil }
        guard let status = OperationStatus(rawValue: object.status) else { return nil }
        var serverSeq: Int?
        if object.serverSeq != 0 {
            serverSeq = Int(object.serverSeq)
        }
        return FileOperation(
            id: object.id,
            fileID: object.fileID,
            deviceID: object.deviceID,
            timestamp: object.timestamp,
            baseCursor: Int(object.baseCursor),
            kind: kind,
            serverSeq: serverSeq,
            status: status
        )
    }
}
